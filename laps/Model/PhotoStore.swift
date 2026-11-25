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
