import Foundation

/// Formats a byte count with units that scale naturally from MB to GB and TB.
public enum ByteFormatter {
    /// Human-readable decimal size, e.g. `512 MB`, `1.2 GB`, `3 TB`.
    ///
    /// Decimal (1000-based) units match how iOS reports storage. Values below
    /// 10 in the chosen unit keep one decimal place; larger values round to a
    /// whole number to stay compact.
    public static func string(fromBytes bytes: Int64) -> String {
        let value = max(0, bytes)
        if value < 1_000 {
            return value == 1 ? "1 byte" : "\(value) bytes"
        }
        let units = ["KB", "MB", "GB", "TB", "PB"]
        var amount = Double(value)
        var unitIndex = -1
        while amount >= 1_000 && unitIndex < units.count - 1 {
            amount /= 1_000
            unitIndex += 1
        }
        if amount.rounded() >= 1_000 && unitIndex < units.count - 1 {
            amount /= 1_000
            unitIndex += 1
        }
        let unit = units[max(0, unitIndex)]
        let formatted: String
        if amount < 10 {
            formatted = String(format: "%.1f", amount)
        } else {
            formatted = String(format: "%.0f", amount)
        }
        return "\(formatted) \(unit)"
    }

    /// Copy for the post-deletion result screen, e.g. "about 1.2 GB".
    public static func approximateString(fromBytes bytes: Int64) -> String {
        "about \(string(fromBytes: bytes))"
    }
}
