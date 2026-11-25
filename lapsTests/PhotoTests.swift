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

    // MARK: - The daily picture

    func testDeterminedNeedsTenWalkingAndGoldLapsCount() {
        func d(_ w: Int, _ s: Int, _ t: Int = 20) -> Int { PictureMath.revealed(walking: w, standing: s, tiles: t, mode: .determined) }
        XCTAssertEqual(d(5, 12), 15)          // standing fills at most 10 of 20
        XCTAssertEqual(d(10, 10), 20)
        XCTAssertEqual(d(13, 7), 20)          // gold laps mean fewer times up
        XCTAssertEqual(d(9, 30), 19)          // can't finish without 10 walking
        XCTAssertEqual(d(10, 6, 16), 16)
        XCTAssertEqual(d(10, 14, 25), 24)
        XCTAssertEqual(d(0, 0), 0)
    }

    func testFlexibleCountsAnyMix() {
        XCTAssertEqual(PictureMath.revealed(walking: 5, standing: 12, tiles: 20, mode: .flexible), 17)
        XCTAssertEqual(PictureMath.revealed(walking: 0, standing: 30, tiles: 16, mode: .flexible), 16)
    }

    func testStatusSaysWhenOnlyWalkingIsLeft() {
        XCTAssertEqual(PictureMath.status(walking: 7, standing: 10, tiles: 20, mode: .determined),
                       "17 of 20 uncovered. 3 more walks to go.")
        XCTAssertEqual(PictureMath.status(walking: 7, standing: 4, tiles: 20, mode: .determined),
                       "11 of 20 uncovered. 9 to go.")
        XCTAssertEqual(PictureMath.status(walking: 10, standing: 10, tiles: 20, mode: .determined),
                       "All 20 uncovered. Beautiful!")
    }

    func testRevealOrderIsScatteredButSameAllDay() {
        let a = PictureMath.order(tiles: 20, seed: "2026-11-25-x")
        XCTAssertEqual(Set(a), Set(0..<20))
        XCTAssertEqual(a, PictureMath.order(tiles: 20, seed: "2026-11-25-x"))
        XCTAssertNotEqual(a, Array(0..<20))
        XCTAssertNotEqual(a, PictureMath.order(tiles: 20, seed: "2026-11-26-x"))
    }

    func testEachDayGetsTheNextPhotoWithoutRepeats() async {
        let photos = PhotoStore(folder: folder)
        let ids = await photos.add((0..<3).map { _ in photoData(width: 400, height: 500) })
        photos.setExcluded(true, for: ids[1])

        let days = ["2026-11-25", "2026-11-26", "2026-11-27", "2026-11-28"]
        let picked = days.map { day -> UUID? in
            let p = photos.pictureForToday(day)
            photos.sync(day: day, walking: 20, standing: 20)   // finish each day
            return p?.photoID
        }
        // Skipped photo left out; a new round starts after both have had a turn.
        XCTAssertEqual(picked, [ids[0], ids[2], ids[0], ids[2]])
        XCTAssertEqual(photos.pictureForToday(days[0])?.photoID, ids[0])   // same photo all day
    }

    func testUnfinishedPictureComesBackLater() async {
        let photos = PhotoStore(folder: folder)
        let ids = await photos.add((0..<3).map { _ in photoData(width: 400, height: 500) })
        photos.sync(day: "2026-11-25", walking: 3, standing: 0)              // not finished
        photos.sync(day: "2026-11-26", walking: 20, standing: 20)
        photos.sync(day: "2026-11-27", walking: 20, standing: 20)
        let p = photos.pictureForToday("2026-11-28")
        XCTAssertEqual(p?.photoID, ids[0])
    }

    func testFinishingSavesToGalleryAndRaisingTheChallengeKeepsIt() async {
        let photos = PhotoStore(folder: folder)
        let ids = await photos.add([photoData(width: 400, height: 500)])
        let day = "2026-11-25"
        photos.updateSettings { $0.tiles = 16 }
        photos.sync(day: day, walking: 10, standing: 6)
        XCTAssertEqual(photos.picture(for: day)?.completedTiles, 16)
        XCTAssertTrue(FileManager.default.fileExists(atPath: photos.galleryURL(day, .picture).path))

        // Raised to 20: the picture shows tiles again, but the gallery keeps the 16.
        photos.updateSettings { $0.tiles = 20 }
        photos.sync(day: day, walking: 10, standing: 6)
        XCTAssertEqual(photos.revealedCount(walking: 10, standing: 6), 16)
        XCTAssertEqual(photos.picture(for: day)?.completedTiles, 16)

        // Reaching 20 records the higher level.
        photos.sync(day: day, walking: 10, standing: 10)
        XCTAssertEqual(photos.picture(for: day)?.completedTiles, 20)

        // Removing the photo from the collection leaves the gallery copy.
        photos.delete(ids[0])
        XCTAssertNotNil(photos.dayImage(photos.picture(for: day)!))
    }

    func testUndoBelowTheFinishTakesItBack() async {
        let photos = PhotoStore(folder: folder)
        await photos.add([photoData(width: 400, height: 500)])
        let day = "2026-11-25"
        photos.sync(day: day, walking: 10, standing: 10)
        XCTAssertNotNil(photos.picture(for: day)?.completedTiles)
        photos.sync(day: day, walking: 9, standing: 10)                    // a mistaken lap undone
        XCTAssertNil(photos.picture(for: day)?.completedTiles)
        XCTAssertFalse(FileManager.default.fileExists(atPath: photos.galleryURL(day, .picture).path))
    }

    func testChangingThePictureNeverTouchesActivity() async {
        let walks = WalkStore(fileURL: folder.appendingPathComponent("walks.json"))
        walks.recordLap()
        let before = walks.walkingCreditsToday
        let photos = PhotoStore(folder: folder)
        await photos.add([photoData(width: 400, height: 500)])
        photos.updateSettings { $0.tiles = 25; $0.mode = .flexible }
        photos.sync(day: walks.todayKey, walking: walks.walkingCreditsToday, standing: walks.standingCreditsToday)
        XCTAssertEqual(walks.walkingCreditsToday, before)
    }

    func testNoPictureWhenOffOrEmpty() async {
        let photos = PhotoStore(folder: folder)
        XCTAssertNil(photos.pictureForToday("2026-11-25"))
        await photos.add([photoData(width: 400, height: 500)])
        photos.updateSettings { $0.isOn = false }
        XCTAssertNil(photos.pictureForToday("2026-11-25"))
    }

    func testGalleryListsFinishedPicturesNewestFirst() async {
        let photos = PhotoStore(folder: folder)
        await photos.add((0..<3).map { _ in photoData(width: 400, height: 500) })
        photos.sync(day: "2026-11-23", walking: 20, standing: 20)
        photos.sync(day: "2026-11-24", walking: 2, standing: 0)       // unfinished: not in the gallery
        photos.sync(day: "2026-11-25", walking: 20, standing: 20)
        XCTAssertEqual(photos.gallery.map(\.day), ["2026-11-25", "2026-11-23"])
        XCTAssertEqual(PhotoStore(folder: folder).gallery.count, 2)
    }
}
