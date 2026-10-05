import AppKit

let destination = URL(fileURLWithPath: CommandLine.arguments[1])
let sizes = [16, 32, 64, 128, 256, 512, 1024]
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
NSColor(calibratedRed: 0.16, green: 0.40, blue: 0.72, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 52, y: 52, width: 920, height: 920), xRadius: 210, yRadius: 210).fill()
let symbol = NSImage(systemSymbolName: "figure.stand", accessibilityDescription: nil)!
    .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 580, weight: .regular))!
NSColor.white.set()
symbol.isTemplate = false
let tinted = NSImage(size: symbol.size)
tinted.lockFocus()
symbol.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
NSColor.white.setFill()
NSRect(origin: .zero, size: symbol.size).fill(using: .sourceAtop)
tinted.unlockFocus()
tinted.draw(in: NSRect(x: 300, y: 200, width: 424, height: 640))
image.unlockFocus()

let family = NSMutableData()
let types: [Int: String] = [16: "icp4", 32: "icp5", 64: "icp6", 128: "ic07", 256: "ic08", 512: "ic09", 1024: "ic10"]
for size in sizes {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    let png = bitmap.representation(using: .png, properties: [:])!
    family.append(types[size]!.data(using: .ascii)!)
    var length = UInt32(png.count + 8).bigEndian
    withUnsafeBytes(of: &length) { family.append($0.baseAddress!, length: 4) }
    family.append(png)
}
var total = UInt32(family.length + 8).bigEndian
var icon = Data("icns".utf8)
withUnsafeBytes(of: &total) { icon.append(contentsOf: $0) }
icon.append(family as Data)
try icon.write(to: destination.appendingPathComponent("AppIcon.icns"))
