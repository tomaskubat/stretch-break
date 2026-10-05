import AppKit
import StretchBreakCore
import StretchBreakMac
import Testing

@Suite @MainActor
struct MenuBarIconTests {
    @Test(arguments: [15, 60, 240], [false, true])
    func countdownColorsFollowConfiguredInterval(interval: Int, dark: Bool) throws {
        let clock = IconTestClock()
        let engine = try BreakEngine(repository: IconTestRepository(), clock: clock)
        var settings = engine.settings
        settings.intervalMinutes = interval
        #expect(engine.updateSettings(settings))
        let total = Double(interval * 60)
        let initial = try pixels(engine, dark: dark)
        #expect(initial.color.greenComponent > initial.color.redComponent)

        clock.now = clock.now.addingTimeInterval(total * 0.6 - 1)
        engine.tick()
        #expect(try pixels(engine, dark: dark).color.greenComponent > initial.color.redComponent)
        clock.now = clock.now.addingTimeInterval(1)
        engine.tick()
        let orange = try pixels(engine, dark: dark)
        #expect(orange.color.redComponent > orange.color.greenComponent)
        #expect(orange.color.greenComponent > orange.color.blueComponent)

        clock.now = clock.now.addingTimeInterval(total * 0.3)
        engine.tick()
        let later = try pixels(engine, dark: dark)
        #expect(later.color.redComponent < orange.color.redComponent)
        #expect(later.color.greenComponent < orange.color.greenComponent)

        clock.now = clock.now.addingTimeInterval(total * 0.1)
        engine.tick()
        let ready = try pixels(engine, dark: dark)
        #expect(engine.activeBreak != nil)
        #expect(ready.color.redComponent > ready.color.greenComponent * 2)
        #expect(initial.mask == orange.mask && orange.mask == later.mask && later.mask == ready.mask)
    }

    @Test func manualBreakAndCompletionUseRedAndGreenPerson() throws {
        let engine = try BreakEngine(repository: IconTestRepository(), clock: IconTestClock())
        let before = try pixels(engine)
        engine.startBreak()
        let active = try pixels(engine)
        #expect(active.color.redComponent > active.color.greenComponent * 2)
        #expect(before.mask == active.mask)
        for draft in engine.drafts { engine.confirm(draft.id) }
        let completed = try pixels(engine)
        #expect(completed.color.greenComponent > completed.color.redComponent)
        #expect(completed.mask == before.mask)
    }

    @Test func pauseAndStorageErrorKeepTheirNeutralSymbols() throws {
        let repository = IconTestRepository()
        let engine = try BreakEngine(repository: repository, clock: IconTestClock())
        let appearance = try #require(NSAppearance(named: .aqua))
        engine.togglePause()
        let paused = try #require(MenuBarIcon.image(for: engine, appearance: appearance))
        #expect(paused.isTemplate)
        #expect(paused.tiffRepresentation == NSImage(systemSymbolName: "pause.circle", accessibilityDescription: nil)?.tiffRepresentation)
        repository.failSave = true
        engine.togglePause()
        let failed = try #require(MenuBarIcon.image(for: engine, appearance: appearance))
        #expect(failed.isTemplate)
        #expect(failed.tiffRepresentation == MenuBarIcon.image(for: nil, appearance: appearance)?.tiffRepresentation)
        #expect(failed.tiffRepresentation != paused.tiffRepresentation)
    }

    private func pixels(_ engine: BreakEngine, dark: Bool = false) throws -> (color: NSColor, mask: [Bool]) {
        let appearance = try #require(NSAppearance(named: dark ? .darkAqua : .aqua))
        let image = try #require(MenuBarIcon.image(for: engine, appearance: appearance))
        #expect(!image.isTemplate)
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 36, pixelsHigh: 36,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let context = try #require(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        image.draw(in: NSRect(x: 0, y: 0, width: 36, height: 36))
        NSGraphicsContext.restoreGraphicsState()
        var mask: [Bool] = []
        var colors: [NSColor] = []
        for y in 0..<36 {
            for x in 0..<36 {
                let color = try #require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                mask.append(color.alphaComponent > 0.5)
                if color.alphaComponent > 0.9 { colors.append(color) }
            }
        }
        #expect(!colors.isEmpty)
        let count = CGFloat(colors.count)
        return (NSColor(srgbRed: colors.reduce(0) { $0 + $1.redComponent } / count,
                        green: colors.reduce(0) { $0 + $1.greenComponent } / count,
                        blue: colors.reduce(0) { $0 + $1.blueComponent } / count, alpha: 1), mask)
    }
}

@MainActor
private final class IconTestClock: TimeSource {
    var now = Date(timeIntervalSince1970: 1_800_000_000)
}

private final class IconTestRepository: StateRepository {
    var failSave = false
    func load() -> LoadedData? { nil }
    func save(state: AppState, record: BreakRecord?) throws {
        if failSave { throw CocoaError(.fileWriteUnknown) }
    }
}
