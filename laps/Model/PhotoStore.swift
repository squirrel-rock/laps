import Foundation
import Observation
import UIKit

/// The picture reward: the photo collection, its settings, and each day's picture.
/// Kept in its own file (photos.json + a Photos folder), apart from his activity records,
/// so nothing done here can change his walks, standing up or charts.
@MainActor
@Observable
final class PhotoStore {
    private(set) var data = PhotoData()
    /// Photos being prepared after an import.
    private(set) var importing = 0
    /// Bumped whenever a picture file changes, so views reload it.
    private(set) var imageVersion = 0

    @ObservationIgnored let folder: URL
    @ObservationIgnored private var cache = NSCache<NSString, UIImage>()

    init(folder: URL = PhotoStore.defaultFolder) {
        self.folder = folder
        if let raw = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder.walks.decode(PhotoData.self, from: raw) {
            data = saved
        }
    }

    nonisolated static var defaultFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pictures", isDirectory: true)
    }

    private var fileURL: URL { folder.appendingPathComponent("photos.json") }
    private var photosFolder: URL { folder.appendingPathComponent("Collection", isDirectory: true) }

    enum Kind: String { case source, picture, thumb }

    nonisolated func url(for id: UUID, _ kind: Kind) -> URL {
        folder.appendingPathComponent("Collection", isDirectory: true)
            .appendingPathComponent("\(id.uuidString)-\(kind.rawValue).jpg")
    }

    // MARK: - Reading

    var photos: [PhotoItem] { data.photos }
    var settings: PictureSettings { data.settings }
    var activePhotos: [PhotoItem] { data.photos.filter { !$0.excluded } }

    func photo(_ id: UUID) -> PhotoItem? { data.photos.first { $0.id == id } }

    /// The cropped picture or its thumbnail, cached in memory.
    func image(for id: UUID, _ kind: Kind = .thumb) -> UIImage? {
        let key = "\(id.uuidString)-\(kind.rawValue)-\(imageVersion)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let img = UIImage(contentsOfFile: url(for: id, kind).path) else { return nil }
        cache.setObject(img, forKey: key)
        return img
    }

    // MARK: - Adding photos

    /// Adds photos (raw data from the photo picker), each with a centered 4:5 crop.
    /// Returns the new photos' IDs, in the order they were chosen.
    @discardableResult
    func add(_ sources: [Data]) async -> [UUID] {
        importing += sources.count
        defer { importing = 0 }
        try? FileManager.default.createDirectory(at: photosFolder, withIntermediateDirectories: true)

        var added: [UUID] = []
        for raw in sources {
            let id = UUID()
            let urls = (url(for: id, .source), url(for: id, .picture), url(for: id, .thumb))
            let made: (Double, Double, CropRect)? = await Task.detached(priority: .userInitiated) {
                guard let image = ImageTools.downsample(raw),
                      let jpeg = ImageTools.jpeg(image) else { return nil }
                let w = Double(image.width), h = Double(image.height)
                let crop = CropRect.centered(imageWidth: w, imageHeight: h)
                do {
                    try jpeg.write(to: urls.0, options: .atomic)
                    try Self.writeCropped(image, crop: crop, picture: urls.1, thumb: urls.2)
                } catch { return nil }
                return (w, h, crop)
            }.value
            if let (w, h, crop) = made {
                data.photos.append(PhotoItem(id: id, crop: crop, sourceWidth: w, sourceHeight: h))
                data.upcoming.append(id)
                added.append(id)
            }
            importing = max(0, importing - 1)
        }
        save()
        return added
    }

    /// Re-crops a photo from its kept source.
    func setCrop(_ crop: CropRect, for id: UUID) async {
        guard photo(id) != nil else { return }
        let c = crop.clamped()
        let urls = (url(for: id, .source), url(for: id, .picture), url(for: id, .thumb))
        let ok = await Task.detached(priority: .userInitiated) {
            guard let image = ImageTools.load(urls.0) else { return false }
            return (try? Self.writeCropped(image, crop: c, picture: urls.1, thumb: urls.2)) != nil
        }.value
        guard ok, let j = data.photos.firstIndex(where: { $0.id == id }) else { return }
        data.photos[j].crop = c
        imageVersion += 1
        save()
    }

    nonisolated private static func writeCropped(_ image: CGImage, crop: CropRect, picture: URL, thumb: URL) throws {
        let big = ImageTools.render(image, crop: crop, size: ImageTools.pictureSize)
        let small = ImageTools.render(image, crop: crop, size: ImageTools.thumbSize)
        guard let b = big.jpegData(compressionQuality: 0.85), let s = small.jpegData(compressionQuality: 0.8) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try b.write(to: picture, options: .atomic)
        try s.write(to: thumb, options: .atomic)
    }

    // MARK: - Managing the collection

    /// Removes a photo from the collection only. The original in Apple Photos is never touched.
    func delete(_ id: UUID) {
        data.photos.removeAll { $0.id == id }
        data.upcoming.removeAll { $0 == id }
        for kind in [Kind.source, .picture, .thumb] {
            try? FileManager.default.removeItem(at: url(for: id, kind))
        }
        save()
    }

    func move(from offsets: IndexSet, to destination: Int) {
        data.photos.move(fromOffsets: offsets, toOffset: destination)
        save()
    }

    func setExcluded(_ excluded: Bool, for id: UUID) {
        guard let i = data.photos.firstIndex(where: { $0.id == id }) else { return }
        data.photos[i].excluded = excluded
        save()
    }

    func updateSettings(_ change: (inout PictureSettings) -> Void) {
        change(&data.settings)
        save()
    }

    // MARK: - The daily picture

    /// What happened on the most recent sync, for the reveal animation.
    struct Reveal: Equatable {
        var day: String
        var count: Int
        var tiles: Int
        var at: Date
    }
    private(set) var lastReveal: Reveal?

    func picture(for day: String) -> DailyPicture? { data.days[day] }

    /// Today's picture, choosing one if the day doesn't have one yet.
    /// Returns nil when the reward is off or there are no photos to use.
    @discardableResult
    func pictureForToday(_ day: String) -> DailyPicture? {
        guard data.settings.isOn else { return nil }
        // Keep today's picture, unless its photo was removed before he finished it.
        if let p = data.days[day], p.isComplete || photo(p.photoID) != nil { return p }
        guard let id = nextPhotoID(for: day) else { return nil }
        let p = DailyPicture(day: day, photoID: id)
        data.days[day] = p
        save()
        return p
    }

    /// The next photo in the rotation. Unfinished pictures from earlier days go to the back of the line,
    /// and nothing repeats until every photo in use has had its turn.
    private func nextPhotoID(for day: String) -> UUID? {
        let usable = Set(activePhotos.map(\.id))
        guard !usable.isEmpty else { return nil }

        for key in data.days.keys.sorted() where key < day {
            guard var p = data.days[key], !p.isComplete, !p.returned else { continue }
            p.returned = true
            data.days[key] = p
            if !data.upcoming.contains(p.photoID) { data.upcoming.append(p.photoID) }
        }

        let inCollection = Set(data.photos.map(\.id))
        data.upcoming.removeAll { !inCollection.contains($0) }   // removed from the collection
        if let i = data.upcoming.firstIndex(where: { usable.contains($0) }) {
            return data.upcoming.remove(at: i)
        }

        // Everyone's had a turn: start a new round, not starting with yesterday's photo.
        var round = activePhotos.map(\.id)
        if data.settings.order == .shuffled {
            var rng = SeededRandom(seed: "round-\(day)")
            round.shuffle(using: &rng)
        }
        let last = data.days.keys.filter { $0 < day }.max().flatMap { data.days[$0]?.photoID }
        if round.count > 1, round.first == last { round.append(round.removeFirst()) }
        data.upcoming = Array(round.dropFirst())
        return round.first
    }

    /// Brings today's picture up to date with his activity. Finishing a picture saves a copy
    /// to the gallery. Raising the challenge afterwards leaves that copy alone; only a real
    /// correction (an undo that drops below what finished it) takes it back.
    func sync(day: String, walking: Int, standing: Int) {
        guard data.settings.isOn, var p = pictureForToday(day) else { return }
        let s = data.settings
        let shown = PictureMath.revealed(walking: walking, standing: standing, tiles: s.tiles, mode: s.mode)

        if shown >= s.tiles {
            if (p.completedTiles ?? 0) < s.tiles {
                p.completedTiles = s.tiles
                p.completedMode = s.mode
                p.completedAt = Date()
                copyToGallery(p)
            }
        } else if let done = p.completedTiles, let mode = p.completedMode,
                  PictureMath.revealed(walking: walking, standing: standing, tiles: done, mode: mode) < done {
            p.completedTiles = nil
            p.completedMode = nil
            p.completedAt = nil
            try? FileManager.default.removeItem(at: galleryURL(day, .picture))
            try? FileManager.default.removeItem(at: galleryURL(day, .thumb))
        }
        if data.days[day] != p { data.days[day] = p; save() }

        let reveal = Reveal(day: day, count: shown, tiles: s.tiles, at: Date())
        if lastReveal?.day != reveal.day || lastReveal?.count != shown || lastReveal?.tiles != s.tiles {
            lastReveal = reveal
        }
    }

    /// Tiles uncovered right now for today's picture.
    func revealedCount(walking: Int, standing: Int) -> Int {
        let s = data.settings
        return PictureMath.revealed(walking: walking, standing: standing, tiles: s.tiles, mode: s.mode)
    }

    // MARK: - Gallery copies

    /// Every finished picture, newest first.
    var gallery: [DailyPicture] {
        data.days.values.filter(\.isComplete).sorted { $0.day > $1.day }
    }

    nonisolated func galleryURL(_ day: String, _ kind: Kind) -> URL {
        folder.appendingPathComponent("Gallery", isDirectory: true)
            .appendingPathComponent("\(day)-\(kind.rawValue).jpg")
    }

    /// Finished pictures keep their own copy, so removing the photo from the collection never removes it here.
    private func copyToGallery(_ p: DailyPicture) {
        let fm = FileManager.default
        try? fm.createDirectory(at: galleryURL(p.day, .picture).deletingLastPathComponent(), withIntermediateDirectories: true)
        for kind in [Kind.picture, .thumb] {
            let to = galleryURL(p.day, kind)
            try? fm.removeItem(at: to)
            try? fm.copyItem(at: url(for: p.photoID, kind), to: to)
        }
    }

    /// The day's picture: the gallery copy once finished, otherwise the collection's.
    func dayImage(_ p: DailyPicture, _ kind: Kind = .picture) -> UIImage? {
        if p.isComplete, let img = UIImage(contentsOfFile: galleryURL(p.day, kind).path) { return img }
        return image(for: p.photoID, kind)
    }

    // MARK: - Saving

    private func save() {
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let raw = try JSONEncoder.walks.encode(data)
            try raw.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            print("laps: failed to save photos – \(error)")
        }
    }
}
