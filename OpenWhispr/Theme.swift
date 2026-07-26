import AppKit
import SwiftUI

enum Theme {
    static let bg = adaptive(light: 0xF8F7F4, dark: 0x171716)
    static let sidebarBg = adaptive(light: 0xF0EFEB, dark: 0x20201E)
    static let sidebarSel = adaptive(light: 0xE5E2DA, dark: 0x34332F)
    static let text = adaptive(light: 0x1B1B1A, dark: 0xF4F3EF)
    static let textSecondary = adaptive(light: 0x72716D, dark: 0xAAA8A1)
    static let divider = adaptive(light: 0xE2E0DA, dark: 0x373632)
    static let fieldBg = adaptive(light: 0xEFEEE9, dark: 0x292825)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? dark
                : light
            return NSColor(
                red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}
