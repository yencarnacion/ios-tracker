import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Render directly into an opaque bitmap without relying on AppKit's current graphics context.
let space = CGColorSpaceCreateDeviceRGB()
let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
    bytesPerRow: 4096, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let coral = CGColor(red: 1, green: 0.33, blue: 0.49, alpha: 1)
let white = CGColor(gray: 1, alpha: 1)
let mint = CGColor(red: 0.13, green: 0.71, blue: 0.60, alpha: 1)
let gradient = CGGradient(colorsSpace: space, colors: [
    CGColor(red: 1, green: 0.53, blue: 0.61, alpha: 1), coral
] as CFArray, locations: [0, 1])!
context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 1024),
    end: CGPoint(x: 1024, y: 0), options: [])

func rounded(_ rect: CGRect, radius: CGFloat, color: CGColor) {
    context.setFillColor(color)
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.fillPath()
}

func line(_ points: [CGPoint], width: CGFloat, color: CGColor) {
    context.setStrokeColor(color)
    context.setLineWidth(width)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.addLines(between: points)
    context.strokePath()
}

context.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: CGColor(gray: 0, alpha: 0.12))
rounded(CGRect(x: 198, y: 170, width: 628, height: 628), radius: 94, color: white)
context.setShadow(offset: .zero, blur: 0, color: nil)
for x in [CGFloat(337), 627] {
    rounded(CGRect(x: x, y: 742, width: 60, height: 110), radius: 30, color: coral)
    rounded(CGRect(x: x + 16, y: 774, width: 28, height: 88), radius: 14, color: white)
}
rounded(CGRect(x: 280, y: 652, width: 464, height: 16), radius: 8,
        color: CGColor(red: 1, green: 0.77, blue: 0.82, alpha: 1))
for (index, y) in [CGFloat(560), 435, 310].enumerated() {
    context.setFillColor(coral)
    context.fillEllipse(in: CGRect(x: 298, y: y - 28, width: 56, height: 56))
    line([CGPoint(x: 313, y: y), CGPoint(x: 323, y: y - 10), CGPoint(x: 340, y: y + 12)], width: 8, color: white)
    rounded(CGRect(x: 394, y: y - 12, width: index == 0 ? 260 : 184, height: 24), radius: 12,
            color: CGColor(red: 1, green: 0.80, blue: 0.84, alpha: 1))
}

context.setFillColor(mint)
context.fillEllipse(in: CGRect(x: 496, y: 164, width: 308, height: 308))
context.setStrokeColor(white)
context.setLineWidth(14)
context.strokeEllipse(in: CGRect(x: 496, y: 164, width: 308, height: 308))
line([CGPoint(x: 650, y: 400), CGPoint(x: 650, y: 318), CGPoint(x: 712, y: 280)], width: 19, color: white)
context.setFillColor(white)
context.fillEllipse(in: CGRect(x: 638, y: 306, width: 24, height: 24))

let image = context.makeImage()!
let suppliedPath = CommandLine.arguments.dropFirst().first
let paths = suppliedPath.map { [$0] } ?? [
    "HabitTracker/Assets.xcassets/AppIcon.appiconset/AppIcon.png",
    "HabitTracker/Assets.xcassets/AppMark.imageset/AppMark.png"
]
for path in paths {
    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let output = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(output, image, nil)
    guard CGImageDestinationFinalize(output) else { fatalError("Unable to write \(path)") }
}
