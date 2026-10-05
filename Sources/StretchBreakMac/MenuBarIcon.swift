import AppKit
import StretchBreakCore

@MainActor
public enum MenuBarIcon {
    public static func image(for engine: BreakEngine?, appearance: NSAppearance) -> NSImage? {
        guard let engine, !engine.hasUnsavedChange else {
            return templateImage("exclamationmark.triangle.fill")
        }
        if engine.isPaused { return templateImage("pause.circle") }

        let elapsed = 1 - engine.remainingSeconds / Double(engine.intervalMinutes * 60)
        let dark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let color: NSColor
        if elapsed >= 1 {
            color = dark ? rgb(255, 114, 111) : rgb(197, 44, 43)
        } else if elapsed < 0.6 {
            color = dark ? rgb(94, 217, 143) : rgb(36, 126, 73)
        } else {
            let start = dark ? rgb(255, 190, 92) : rgb(190, 117, 18)
            let end = dark ? rgb(240, 134, 57) : rgb(135, 65, 18)
            color = start.blended(withFraction: (elapsed - 0.6) / 0.4, of: end) ?? start
        }
        let configuration = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        let image = NSImage(systemSymbolName: "figure.stand", accessibilityDescription: "StretchBreak")?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = false
        return image
    }

    private static func templateImage(_ symbol: String) -> NSImage? {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "StretchBreak")
        image?.isTemplate = true
        return image
    }

    private static func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> NSColor {
        NSColor(srgbRed: red / 255, green: green / 255, blue: blue / 255, alpha: 1)
    }
}
