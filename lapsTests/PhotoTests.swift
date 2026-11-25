import UIKit
import XCTest
@testable import laps

@MainActor
final class PhotoTests: XCTestCase {
    private var folder: URL!

    override func setUp() {
        super.setUp()
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: folder)
        super.tearDown()
    }

    /// A plain JPEG of the given size, like a photo from the library.
    private func photoData(width: Int, height: Int) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
            .jpegData(withCompressionQuality: 0.8) { ctx in
                UIColor.orange.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            }
    }

    func testCenteredCropIsFourByFive() {
        let wide = CropRect.centered(imageWidth: 3000, imageHeight: 2000)   // landscape
        XCTAssertEqual(wide.height, 1)
        XCTAssertEqual(wide.width * 3000 / 2000, 0.8, accuracy: 0.0001)
        XCTAssertEqual(wide.x, (1 - wide.width) / 2, accuracy: 0.0001)

        let tall = CropRect.centered(imageWidth: 1000, imageHeight: 2000)   // tall portrait
        XCTAssertEqual(tall.width, 1)
        XCTAssertEqual(1000 / (tall.height * 2000), 0.8, accuracy: 0.0001)
    }

    func testCropStaysInsideThePhoto() {
        let c = CropRect(x: 0.9, y: -0.2, width: 0.5, height: 0.5).clamped()
        XCTAssertEqual(c.x, 0.5, accuracy: 0.0001)
        XCTAssertEqual(c.y, 0)
    }

    func testAddingPhotosKeepsSmallCopiesAndAPictureAndSaves() async throws {
        let photos = PhotoStore(folder: folder)
        let ids = await photos.add([photoData(width: 4000, height: 3000), photoData(width: 600, height: 900)])
        XCTAssertEqual(ids.count, 2)
        XCTAssertEqual(photos.photos.map(\.id), ids)
        XCTAssertEqual(photos.data.upcoming, ids)

        // The kept source is scaled down; the picture is 4:5.
        let first = try XCTUnwrap(photos.photo(ids[0]))
        XCTAssertEqual(max(first.sourceWidth, first.sourceHeight), Double(ImageTools.sourceMaxPixels))
        let picture = try XCTUnwrap(UIImage(contentsOfFile: photos.url(for: ids[0], .picture).path))
        XCTAssertEqual(picture.size, ImageTools.pictureSize)
        XCTAssertNotNil(photos.image(for: ids[1], .thumb))

        // Saved and read back.
        XCTAssertEqual(PhotoStore(folder: folder).photos.map(\.id), ids)
    }

    func testUnreadablePhotoIsLeftOut() async {
        let photos = PhotoStore(folder: folder)
        let ids = await photos.add([Data("not a photo".utf8)])
        XCTAssertTrue(ids.isEmpty)
        XCTAssertTrue(photos.photos.isEmpty)
    }

    func testRemoveSkipAndReorder() async {
        let photos = PhotoStore(folder: folder)
        let ids = await photos.add((0..<3).map { _ in photoData(width: 400, height: 500) })

        photos.setExcluded(true, for: ids[1])
        XCTAssertEqual(photos.activePhotos.map(\.id), [ids[0], ids[2]])

        photos.move(from: IndexSet(integer: 2), to: 0)
        XCTAssertEqual(photos.photos.map(\.id), [ids[2], ids[0], ids[1]])

        photos.delete(ids[0])
        XCTAssertEqual(photos.photos.map(\.id), [ids[2], ids[1]])
        XCTAssertFalse(photos.data.upcoming.contains(ids[0]))
        XCTAssertFalse(FileManager.default.fileExists(atPath: photos.url(for: ids[0], .source).path))
    }

    func testRecroppingIsSaved() async throws {
        let photos = PhotoStore(folder: folder)
        let added = await photos.add([photoData(width: 3000, height: 2000)])
        let id = try XCTUnwrap(added.first)
        let crop = CropRect(x: 0, y: 0, width: 0.3, height: 0.675)
        await photos.setCrop(crop, for: id)
        XCTAssertEqual(PhotoStore(folder: folder).photo(id)?.crop, crop)
    }

    func testPictureSettingsAndGrids() {
        let photos = PhotoStore(folder: folder)
        XCTAssertEqual(photos.settings.tiles, 20)
        XCTAssertEqual(photos.settings.mode, .determined)
        photos.updateSettings { $0.tiles = 25; $0.mode = .flexible }
        XCTAssertEqual(PhotoStore(folder: folder).settings.tiles, 25)
        XCTAssertTrue(PictureSettings.grid(tiles: 16) == (4, 4))
        XCTAssertTrue(PictureSettings.grid(tiles: 20) == (4, 5))
        XCTAssertTrue(PictureSettings.grid(tiles: 25) == (5, 5))
    }
}
