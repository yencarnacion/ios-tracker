import AppKit

let size = NSSize(width: 1024, height: 1024)
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
    bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let background = NSBezierPath(rect: NSRect(origin: .zero, size: size))
NSGradient(starting: NSColor(srgbRed: 1, green: 0.52, blue: 0.56, alpha: 1),
           ending: NSColor(srgbRed: 1, green: 0.30, blue: 0.48, alpha: 1))!.draw(in: background, angle: -70)
let center = NSPoint(x: 512, y: 525)
NSColor.white.withAlphaComponent(0.18).setFill()
NSBezierPath(ovalIn: NSRect(x: 156, y: 169, width: 712, height: 712)).fill()
NSColor.white.setFill()
for index in 0..<5 {
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: center.x, yBy: center.y)
    transform.concat()
    let rotation = NSAffineTransform()
    rotation.rotate(byDegrees: CGFloat(index) * 72)
    rotation.concat()
    NSBezierPath(ovalIn: NSRect(x: -115, y: -8, width: 230, height: 292)).fill()
    NSGraphicsContext.restoreGraphicsState()
}
NSColor(srgbRed: 1, green: 0.36, blue: 0.49, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 364, y: 377, width: 296, height: 296)).fill()
let check = NSBezierPath()
check.move(to: NSPoint(x: 432, y: 522)); check.line(to: NSPoint(x: 489, y: 467)); check.line(to: NSPoint(x: 594, y: 583))
check.lineWidth = 31; check.lineCapStyle = .round; check.lineJoinStyle = .round
NSColor.white.setStroke(); check.stroke()
NSGraphicsContext.restoreGraphicsState()
let png = bitmap.representation(using: .png, properties: [:])!
let target = CommandLine.arguments.dropFirst().first ?? "HabitTracker/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
try png.write(to: URL(fileURLWithPath: target))
