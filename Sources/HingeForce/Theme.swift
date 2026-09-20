import SwiftUI

enum Theme {
    static let background = Color.white
    static let yellow = Color(red: 0.99, green: 0.71, blue: 0.09)
    static let track = Color(white: 0.935)
    static let green = Color(red: 0.47, green: 0.94, blue: 0.05)
    static let pill = Color(white: 0.935)
    /// The grey a button's background turns to while the pointer is over it: #E3E3E3.
    static let pillHover = RGB(hex: 0xE3E3E3).color
    static let yellowHover = Color(red: 0.99 * 0.92, green: 0.71 * 0.92, blue: 0.09 * 0.92)
    static let pillText = Color(white: 0.27)
    /// The cake's cut line, before it turns white.
    static let cutLine = (red: 0xB5 / 255.0, green: 0x96 / 255.0, blue: 0xE5 / 255.0)
    /// The lighter lavender the slice of cake between the start line and the knife is tinted.
    static let sliceHighlight = Color(red: 0xDD / 255, green: 0xCD / 255, blue: 0xF7 / 255)
    static let smoke = Color(red: 0xD6 / 255, green: 0xE4 / 255, blue: 0xE9 / 255)
    static let title = Color.black
    static let subtitle = Color(white: 0.42)
}
