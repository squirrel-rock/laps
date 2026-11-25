import Foundation

/// The part of a photo that shows in the 4:5 frame, as fractions of the stored source image (0–1).
struct CropRect: Codable, Hashable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    /// The portrait shape every picture uses, whatever the number of tiles.
    static let aspect = 4.0 / 5.0

    /// The largest centered 4:5 area of an image of this size.
    static func centered(imageWidth w: Double, imageHeight h: Double) -> CropRect {
        guard w > 0, h > 0 else { return CropRect(x: 0, y: 0, width: 1, height: 1) }
        if w / h > aspect {                      // wider than 4:5: trim the sides
            let cw = h * aspect / w
            return CropRect(x: (1 - cw) / 2, y: 0, width: cw, height: 1)
        } else {                                  // taller: trim top and bottom
            let ch = w / aspect / h
            return CropRect(x: 0, y: (1 - ch) / 2, width: 1, height: ch)
        }
    }

    /// Keeps the rect inside the image.
    func clamped() -> CropRect {
        let w = min(1, max(0.01, width)), h = min(1, max(0.01, height))
        return CropRect(x: min(max(0, x), 1 - w), y: min(max(0, y), 1 - h), width: w, height: h)
    }
}

/// One photograph in the reward collection.
struct PhotoItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var addedAt = Date()
    /// Left out of the rotation for now, without deleting it.
    var excluded = false
    var crop: CropRect
    /// Pixel size of the stored source, for re-cropping.
    var sourceWidth: Double
    var sourceHeight: Double
}

enum RewardMode: String, Codable, CaseIterable, Identifiable {
    /// Ten walking credits, the rest from standing up.
    case determined
    /// Any mix of walking and standing up.
    case flexible

    var id: String { rawValue }
    var title: String { self == .determined ? "Determined" : "Flexible" }
}

enum PhotoOrder: String, Codable, CaseIterable, Identifiable {
    case inOrder, shuffled
    var id: String { rawValue }
    var title: String { self == .inOrder ? "In order" : "Shuffled" }
}

struct PictureSettings: Codable, Hashable {
    var isOn = true
    /// 16, 20 or 25.
    var tiles = 20
    var mode = RewardMode.determined
    var order = PhotoOrder.inOrder

    static let tileChoices = [16, 20, 25]

    /// Columns × rows for each challenge.
    static func grid(tiles: Int) -> (columns: Int, rows: Int) {
        switch tiles {
        case 16: return (4, 4)
        case 25: return (5, 5)
        default: return (4, 5)
        }
    }
}

/// The picture for one day.
struct DailyPicture: Codable, Hashable {
    var day: String
    var photoID: UUID
    /// The highest challenge he finished that day (16, 20 or 25), once he has.
    var completedTiles: Int?
    var completedMode: RewardMode?
    var completedAt: Date?
}

struct PhotoData: Codable {
    var version = 1
    /// The collection, in his chosen order.
    var photos: [PhotoItem] = []
    var settings = PictureSettings()
    /// Photo IDs still to come before the collection starts over.
    var upcoming: [UUID] = []
    var days: [String: DailyPicture] = [:]
}

// Fields added later fall back to defaults, as in walks.json.
extension PictureSettings {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isOn = try c.decodeIfPresent(Bool.self, forKey: .isOn) ?? true
        tiles = try c.decodeIfPresent(Int.self, forKey: .tiles) ?? 20
        mode = try c.decodeIfPresent(RewardMode.self, forKey: .mode) ?? .determined
        order = try c.decodeIfPresent(PhotoOrder.self, forKey: .order) ?? .inOrder
    }
}

extension PhotoData {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        photos = try c.decodeIfPresent([PhotoItem].self, forKey: .photos) ?? []
        settings = try c.decodeIfPresent(PictureSettings.self, forKey: .settings) ?? PictureSettings()
        upcoming = try c.decodeIfPresent([UUID].self, forKey: .upcoming) ?? []
        days = try c.decodeIfPresent([String: DailyPicture].self, forKey: .days) ?? [:]
    }
}
