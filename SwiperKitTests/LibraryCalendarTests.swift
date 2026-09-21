import XCTest
@testable import SwiperKit

final class LibraryCalendarTests: XCTestCase {
    /// A fixed calendar so the tests do not depend on the machine's time zone or
    /// first weekday.
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func asset(_ id: String, _ date: Date?) -> AssetDescriptor {
        AssetDescriptor(
            id: id,
            creationDate: date,
            pixelWidth: 4_032,
            pixelHeight: 3_024,
            isFavorite: false,
            kind: .photo
        )
    }

    func testGroupsAssetsIntoTheirCalendarMonths() {
        let order = LibraryOrder([
            asset("jan-a", date(2024, 1, 5)),
            asset("jan-b", date(2024, 1, 28)),
            asset("feb-a", date(2024, 2, 2)),
        ])
        let months = LibraryCalendar.months(in: order, newestFirst: false, calendar: calendar)

        XCTAssertEqual(months.map(\.id), ["2024-01", "2024-02"])
        XCTAssertEqual(months[0].assets.map(\.id), ["jan-a", "jan-b"])
        XCTAssertEqual(months[1].assets.map(\.id), ["feb-a"])
        XCTAssertEqual(months[0].count, 2)
        XCTAssertFalse(months[0].isUndated)
    }

    func testNewestFirstReversesBothMonthsAndAssetsWithinThem() {
        let order = LibraryOrder([
            asset("jan-a", date(2024, 1, 5)),
            asset("jan-b", date(2024, 1, 28)),
            asset("feb-a", date(2024, 2, 2)),
        ])
        let months = LibraryCalendar.months(in: order, newestFirst: true, calendar: calendar)

        XCTAssertEqual(months.map(\.id), ["2024-02", "2024-01"])
        XCTAssertEqual(months[1].assets.map(\.id), ["jan-b", "jan-a"], "the month's newest photo comes first")
    }

    func testDecemberAndJanuaryAreDifferentMonthsAcrossTheYearBoundary() {
        let order = LibraryOrder([
            asset("dec", date(2023, 12, 31, 23)),
            asset("jan", date(2024, 1, 1, 1)),
        ])
        let months = LibraryCalendar.months(in: order, newestFirst: true, calendar: calendar)
        XCTAssertEqual(months.map(\.id), ["2024-01", "2023-12"])
    }

    func testUndatedAssetsComeLastWhateverTheOrder() {
        let order = LibraryOrder([
            asset("known", date(2024, 3, 3)),
            asset("unknown", nil),
        ])
        for newestFirst in [true, false] {
            let months = LibraryCalendar.months(in: order, newestFirst: newestFirst, calendar: calendar)
            XCTAssertEqual(months.last?.id, "undated", "newestFirst: \(newestFirst)")
            XCTAssertTrue(months.last?.isUndated ?? false)
            XCTAssertEqual(months.last?.assets.map(\.id), ["unknown"])
        }
    }

    func testEmptyLibraryProducesNoMonths() {
        XCTAssertTrue(LibraryCalendar.months(in: .empty, calendar: calendar).isEmpty)
    }

    func testEveryAssetAppearsExactlyOnce() {
        let order = TestLibrary.order()
        let months = LibraryCalendar.months(in: order, newestFirst: true, calendar: calendar)
        let ids = months.flatMap { $0.assets.map(\.id) }
        XCTAssertEqual(ids.count, order.count)
        XCTAssertEqual(Set(ids), order.idSet)
    }

    func testTitleIsLocalised() {
        let order = LibraryOrder([asset("a", date(2024, 11, 9))])
        let months = LibraryCalendar.months(in: order, calendar: calendar)

        let english = LibraryCalendar.titles(
            for: months,
            locale: Locale(identifier: "en_US"),
            calendar: calendar
        )
        XCTAssertEqual(english["2024-11"], "November 2024")

        let chinese = LibraryCalendar.titles(
            for: months,
            locale: Locale(identifier: "zh_Hans_CN"),
            calendar: calendar
        )
        XCTAssertEqual(chinese["2024-11"], "2024年11月")
    }

    func testUndatedTitleIsSuppliedByTheCaller() {
        let order = LibraryOrder([asset("unknown", nil)])
        let months = LibraryCalendar.months(in: order, calendar: calendar)
        let titles = LibraryCalendar.titles(for: months, locale: Locale(identifier: "en_US"), calendar: calendar)
        XCTAssertEqual(titles["undated"], "No date")
    }

    func testMonthKeyIsZeroPaddedAndLocaleIndependent() {
        let start = date(2024, 3, 1)
        XCTAssertEqual(LibraryCalendar.monthKey(for: start, calendar: calendar), "2024-03")
    }
}
