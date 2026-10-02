import Foundation

/// One calendar month of the library, as the Start Here grid presents it.
public struct LibraryMonth: Identifiable, Equatable, Sendable {
    /// Stable identifier, `"2023-11"`, or `"undated"`.
    public let id: String
    /// The first instant of the month, or `nil` for assets with no date.
    public let startDate: Date?
    public let assets: [AssetDescriptor]

    public init(id: String, startDate: Date?, assets: [AssetDescriptor]) {
        self.id = id
        self.startDate = startDate
        self.assets = assets
    }

    public var count: Int { assets.count }
    public var isUndated: Bool { startDate == nil }
}

/// Groups a library into months so Start Here can label where the user is and
/// jump straight to a point in time, instead of making them scroll from one end.
public enum LibraryCalendar {
    /// Groups `order` into months.
    ///
    /// `newestFirst` decides both the order of the months and the order within
    /// each month, because a grid of recent photos is what people look for
    /// first. Assets with no creation date always come last.
    public static func months(
        in order: LibraryOrder,
        newestFirst: Bool = true,
        calendar: Calendar = .current
    ) -> [LibraryMonth] {
        var buckets: [String: (start: Date, assets: [AssetDescriptor])] = [:]
        var order_of_keys: [String] = []
        var undated: [AssetDescriptor] = []

        for asset in order.assets {
            guard
                let date = asset.creationDate,
                let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date))
            else {
                undated.append(asset)
                continue
            }
            let key = monthKey(for: start, calendar: calendar)
            if buckets[key] == nil {
                buckets[key] = (start: start, assets: [])
                order_of_keys.append(key)
            }
            buckets[key]?.assets.append(asset)
        }

        var months = order_of_keys.compactMap { key -> LibraryMonth? in
            guard let bucket = buckets[key] else { return nil }
            let assets = newestFirst ? bucket.assets.reversed() : bucket.assets
            return LibraryMonth(id: key, startDate: bucket.start, assets: Array(assets))
        }
        months.sort { lhs, rhs in
            guard let l = lhs.startDate, let r = rhs.startDate else { return false }
            return newestFirst ? l > r : l < r
        }

        if !undated.isEmpty {
            let assets = newestFirst ? undated.reversed() : undated
            months.append(LibraryMonth(id: "undated", startDate: nil, assets: Array(assets)))
        }
        return months
    }

    /// A localised title for each month, e.g. `"November 2023"` or `"2023年11月"`.
    ///
    /// Returned as a dictionary so the view computes it once per library change
    /// with a single formatter, rather than rebuilding one per row per redraw.
    public static func titles(
        for months: [LibraryMonth],
        locale: Locale = .current,
        calendar: Calendar = .current,
        undatedTitle: String = "No date"
    ) -> [String: String] {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")

        var result: [String: String] = [:]
        for month in months {
            if let start = month.startDate {
                result[month.id] = formatter.string(from: start)
            } else {
                result[month.id] = undatedTitle
            }
        }
        return result
    }

    /// `"2023-11"`, stable regardless of locale.
    static func monthKey(for start: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month], from: start)
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        return String(format: "%04d-%02d", year, month)
    }
}
