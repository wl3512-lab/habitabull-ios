//
// the one place colors and type live, copied from the web app's app/globals.css.
// change a value here and every screen changes with it

import SwiftUI

// lets a color be written as Color(hex: 0x16181D), the same number as in the CSS
extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// written this way so screens can say .foregroundStyle(.fg), not Color.fg
extension ShapeStyle where Self == Color {
    static var ground: Color { Color(hex: 0x16181D) }   // the app background
    static var card: Color { Color(hex: 0x1F232B) }     // raised panels
    static var raise: Color { Color(hex: 0x2A2F39) }    // anything you press
    static var lineStrong: Color { Color(hex: 0x6A788F) } // edge of a control
    static var fg: Color { Color(hex: 0xF4F6F7) }       // main text
    static var dim: Color { Color(hex: 0x9AA3AE) }      // quieter text
    static var brandCyan: Color { Color(hex: 0x8EB4BD) } // quiet actions. not .cyan, SwiftUI has its own
    static var action: Color { Color(hex: 0xD57E5C) }   // the one main action
    static var done: Color { Color(hex: 0x6BB88D) }     // finished
    static var fault: Color { Color(hex: 0xD9746D) }    // something went wrong in the app
}

// relativeTo means the text still grows with the phone's text size setting
extension Font {
    static let hero = Font.custom("BarlowCondensed-Bold", size: 56, relativeTo: .largeTitle)
    static let figure = Font.custom("BarlowCondensed-Bold", size: 44, relativeTo: .largeTitle)
    static let titleText = Font.custom("BarlowCondensed-Bold", size: 26, relativeTo: .title)
        static let head = Font.custom("Barlow-SemiBold", size: 17, relativeTo: .headline)
    static let emphasis = Font.custom("Barlow-Medium", size: 17, relativeTo: .body)
    static let bodyText = Font.custom("Barlow-Regular", size: 15, relativeTo: .subheadline)
    static let captionText = Font.custom("Barlow-Regular", size: 13, relativeTo: .caption)
    static let label = Font.custom("Barlow-SemiBold", size: 11, relativeTo: .caption2)
}
