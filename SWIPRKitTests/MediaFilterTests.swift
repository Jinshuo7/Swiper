import XCTest
@testable import SWIPRKit

final class MediaFilterTests: XCTestCase {
    private func descriptor(
        id: String,
        dayOffset: Int,
        kind: MediaKind,
        isScreenshot: Bool = false,
        isPanorama: Bool = false
    ) -> AssetDescriptor {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        return AssetDescriptor(
            id: id,
            creationDate: base.addingTimeInterval(Double(dayOffset) * 86_400),
            pixelWidth: 4_032,
            pixelHeight: 3_024,
            kind: kind,
            isScreenshot: isScreenshot,
            isPanorama: isPanorama
        )
    }

    /// One asset per category plus the two overlaps, in creation order.
    private var mixed: [AssetDescriptor] {
        [
            descriptor(id: "other-photo", dayOffset: 0, kind: .photo),
            descriptor(id: "screenshot", dayOffset: 1, kind: .photo, isScreenshot: true),
            descriptor(id: "panorama", dayOffset: 2, kind: .photo, isPanorama: true),
            descriptor(id: "live-photo", dayOffset: 3, kind: .livePhoto),
            descriptor(id: "live-screenshot", dayOffset: 4, kind: .livePhoto, isScreenshot: true),
            descriptor(id: "live-panorama", dayOffset: 5, kind: .livePhoto, isPanorama: true),
            descriptor(id: "video", dayOffset: 6, kind: .video),
        ]
    }

    private var order: LibraryOrder { LibraryOrder(mixed) }

    private let allCategories = Set(MediaCategory.allCases)
    private let photoCategories: Set<MediaCategory> = [.screenshot, .livePhoto, .panorama, .otherPhoto]

    // MARK: - Presets

    func testEverythingSelectsAllFiveCategories() {
        XCTAssertEqual(MediaFilter.everything.categories, allCategories)
        XCTAssertEqual(allCategories.count, 5)
    }

    func testPhotosSelectsTheFourPhotoCategories() {
        XCTAssertEqual(MediaFilter.photos.categories, photoCategories)
        XCTAssertFalse(MediaFilter.photos.categories.contains(.video))
    }

    func testVideosSelectsOnlyVideos() {
        XCTAssertEqual(MediaFilter.videos.categories, [.video])
    }

    func testEmptySelectsNothing() {
        XCTAssertTrue(MediaFilter.empty.isEmpty)
        XCTAssertEqual(MediaFilter.empty.categories, [])
    }

    // MARK: - Selection mutations

    func testToggleChangesOneCategoryWithoutDisturbingOthers() {
        var filter = MediaFilter.photos
        filter.toggle(.video)
        XCTAssertEqual(filter.categories, allCategories)
        filter.toggle(.video)
        XCTAssertEqual(filter.categories, photoCategories)
    }

    func testSelectOnlyIsolatesOneCategory() {
        var filter = MediaFilter.everything
        filter.selectOnly(.screenshot)
        XCTAssertEqual(filter.categories, [.screenshot])
        filter.selectOnly(.video)
        XCTAssertEqual(filter.categories, [.video])
    }

    func testFreshPresetNeverReusesPriorExclusions() {
        var filter = MediaFilter.everything
        filter.toggle(.video)
        filter.toggle(.livePhoto)
        // Assigning a preset replaces the selection outright.
        filter = .photos
        XCTAssertEqual(filter.categories, photoCategories)
        filter = .everything
        XCTAssertEqual(filter.categories, allCategories)
    }

    // MARK: - Exclusion-wins matching

    func testIncludesOverlapOnlyWhenAllItsCategoriesAreSelected() {
        let liveScreenshot = mixed[4]
        XCTAssertEqual(liveScreenshot.categories, [.livePhoto, .screenshot])

        XCTAssertTrue(MediaFilter.everything.includes(liveScreenshot))
        XCTAssertTrue(MediaFilter.photos.includes(liveScreenshot))

        var onlyScreenshot = MediaFilter.empty
        onlyScreenshot.selectOnly(.screenshot)
        XCTAssertFalse(onlyScreenshot.includes(liveScreenshot))

        var both = MediaFilter.empty
        both.toggle(.screenshot)
        both.toggle(.livePhoto)
        XCTAssertTrue(both.includes(liveScreenshot))
    }

    func testPlainPhotoNeedsOtherPhotoSelected() {
        let plain = mixed[0]
        XCTAssertTrue(MediaFilter.photos.includes(plain))
        XCTAssertFalse(MediaFilter.videos.includes(plain))
    }

    func testVideoNeedsVideoSelected() {
        let video = mixed[6]
        XCTAssertTrue(MediaFilter.videos.includes(video))
        XCTAssertFalse(MediaFilter.photos.includes(video))
    }

    // MARK: - Pool membership

    func testApplyEverythingEmitsEachAssetOnceInOrder() {
        let result = MediaFilter.everything.apply(to: order)
        XCTAssertEqual(result.ids, order.ids)
        XCTAssertEqual(result.count, 7)
    }

    func testApplyPhotosKeepsOverlapsAndDropsVideo() {
        let result = MediaFilter.photos.apply(to: order)
        XCTAssertEqual(
            result.ids,
            ["other-photo", "screenshot", "panorama", "live-photo", "live-screenshot", "live-panorama"]
        )
        // The overlapping assets appear exactly once each.
        XCTAssertEqual(result.ids.filter { $0 == "live-screenshot" }.count, 1)
        XCTAssertEqual(result.ids.filter { $0 == "live-panorama" }.count, 1)
    }

    func testApplyVideosReturnsOnlyVideo() {
        XCTAssertEqual(MediaFilter.videos.apply(to: order).ids, ["video"])
    }

    func testEmptySelectionProducesEmptyPool() {
        XCTAssertTrue(MediaFilter.empty.apply(to: order).isEmpty)
    }

    func testDisjointSelectionProducesEmptyPool() {
        // Videos only, against a photo-only library.
        let photoOnly = LibraryOrder(Array(mixed.dropLast()))
        let result = MediaFilter.videos.apply(to: photoOnly)
        XCTAssertTrue(result.isEmpty)
        XCTAssertFalse(MediaFilter.videos.isEmpty)
    }

    // MARK: - Summary

    func testSelectionNameForPresets() {
        XCTAssertEqual(MediaFilter.everything.selectionName, "Everything")
        XCTAssertEqual(MediaFilter.photos.selectionName, "Photos")
        XCTAssertEqual(MediaFilter.videos.selectionName, "Videos")
        XCTAssertEqual(MediaFilter.empty.selectionName, "Nothing selected")
    }

    func testSelectionNameForCustomSelections() {
        var filter = MediaFilter.empty
        filter.selectOnly(.screenshot)
        XCTAssertEqual(filter.selectionName, "Screenshots")

        filter.toggle(.video)
        XCTAssertEqual(filter.selectionName, "Screenshots, Videos")
    }

    func testSummaryNamesSelectionAndMatchingCount() {
        XCTAssertEqual(MediaFilter.everything.summary(matchingCount: 7), "Everything · 7 items")
        XCTAssertEqual(MediaFilter.photos.summary(matchingCount: 6), "Photos · 6 items")
        XCTAssertEqual(MediaFilter.videos.summary(matchingCount: 1), "Videos · 1 item")
        XCTAssertEqual(MediaFilter.empty.summary(matchingCount: 0), "Nothing selected · 0 items")
    }

    func testAppliedPoolCountFeedsTheSummary() {
        let photos = MediaFilter.photos.apply(to: order)
        XCTAssertEqual(photos.count, 6)
        XCTAssertEqual(MediaFilter.photos.summary(matchingCount: photos.count), "Photos · 6 items")

        var onlyScreenshot = MediaFilter.empty
        onlyScreenshot.selectOnly(.screenshot)
        let screenshots = onlyScreenshot.apply(to: order)
        XCTAssertEqual(screenshots.ids, ["screenshot"])
        XCTAssertEqual(onlyScreenshot.summary(matchingCount: screenshots.count), "Screenshots · 1 item")
    }
}
