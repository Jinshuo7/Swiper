import SwiftUI
import UIKit

/// Semantic colours for the photo-cleanup UI. Dynamic providers keep the same
/// designed palette legible in both system appearances without forcing a mode.
extension Color {
    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }

    static let swiprBackground = adaptive(light: 0xF4F3F0, dark: 0x111216)
    static let swiprSurface = adaptive(light: 0xFFFFFF, dark: 0x1B1C21)
    static let swiprElevated = adaptive(light: 0xECEAE6, dark: 0x25262B)
    static let swiprForeground = adaptive(light: 0x191A1E, dark: 0xF7F6F3)
    static let swiprSecondary = adaptive(light: 0x5D5E65, dark: 0xB9BAC2)
    static let swiprTertiary = adaptive(light: 0x74757C, dark: 0x999AA2)
    static let swiprBorder = adaptive(light: 0xD8D6D1, dark: 0x393A40)
    static let swiprAccent = adaptive(light: 0xB33A30, dark: 0xC44238)
    static let swiprDelete = adaptive(light: 0xC63F38, dark: 0xFF766D)
    static let swiprKeep = adaptive(light: 0x277A56, dark: 0x68D59A)
    static let swiprWarning = adaptive(light: 0x98530B, dark: 0xFFBE69)
}
