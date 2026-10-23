import AppKit
import SwiftUI

enum Brand {
    static var accent: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(srgbRed: 154 / 255, green: 124 / 255, blue: 255 / 255, alpha: 1)
                : NSColor(srgbRed: 107 / 255, green: 63 / 255, blue: 212 / 255, alpha: 1)
        })
    }

    static var menuBarImage: NSImage {
        guard let image = Bundle.main.image(forResource: "menubar") else {
            return NSImage(systemSymbolName: "rectangle.stack", accessibilityDescription: "Glean") ?? NSImage()
        }
        image.isTemplate = true
        return image
    }
}
