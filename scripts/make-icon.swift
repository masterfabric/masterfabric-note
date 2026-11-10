// Renders the app icon: a black marble composition-book cover with a "NOTE" label plate.
// Usage: swift scripts/make-icon.swift <output.png>
import AppKit
import CoreGraphics

struct Rng {
    var s: UInt64 = 0xC0FFEE1234
    mutating func next() -> CGFloat {
        s &+= 0x9E3779B97F4A7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z ^= z >> 31
        return CGFloat(z % 1_000_000) / 1_000_000
    }
    mutating func range(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * next() }
}

let S: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
let gc = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = gc
let ctx = gc.cgContext

// Board
ctx.setFillColor(CGColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: S, height: S))

// Marble speckle
var rng = Rng()
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
for _ in 0..<560 {
    let cx = rng.range(0, S), cy = rng.range(0, S)
    let r = rng.range(6, 17)
    for _ in 0..<(2 + Int(rng.range(0, 2.99))) {
        let ox = rng.range(-r, r) * 1.3, oy = rng.range(-r, r) * 1.3
        let rx = r * rng.range(0.5, 1.25), ry = r * rng.range(0.4, 1.0)
        ctx.saveGState()
        ctx.translateBy(x: cx + ox, y: cy + oy)
        ctx.rotate(by: rng.range(0, .pi))
        ctx.fillEllipse(in: CGRect(x: -rx, y: -ry, width: 2 * rx, height: 2 * ry))
        ctx.restoreGState()
    }
}

// Spine
let spine = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                       colors: [CGColor(gray: 0.02, alpha: 1), CGColor(gray: 0.14, alpha: 1), CGColor(gray: 0.03, alpha: 1)] as CFArray,
                       locations: [0, 0.55, 1])!
ctx.saveGState()
ctx.clip(to: CGRect(x: 0, y: 0, width: 132, height: S))
ctx.drawLinearGradient(spine, start: .zero, end: CGPoint(x: 132, y: 0), options: [])
ctx.restoreGState()

// Label plate
let plate = CGRect(x: 232, y: 330, width: 692, height: 400)
ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 18, color: CGColor(gray: 0, alpha: 0.45))
ctx.setFillColor(CGColor(gray: 1, alpha: 1))
ctx.addPath(CGPath(roundedRect: plate, cornerWidth: 74, cornerHeight: 74, transform: nil))
ctx.fillPath()
ctx.setShadow(offset: .zero, blur: 0, color: nil)
ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))
ctx.setLineWidth(11)
ctx.addPath(CGPath(roundedRect: plate.insetBy(dx: 22, dy: 22), cornerWidth: 54, cornerHeight: 54, transform: nil))
ctx.strokePath()

// Title
let style = NSMutableParagraphStyle()
style.alignment = .center
let title = NSAttributedString(string: "NOTE", attributes: [
    .font: NSFont.systemFont(ofSize: 150, weight: .black),
    .foregroundColor: NSColor.black,
    .kern: 14,
    .paragraphStyle: style,
])
title.draw(in: CGRect(x: plate.minX, y: plate.maxY - 222, width: plate.width, height: 180))

// Ruled lines
ctx.setLineWidth(7)
for y in [plate.minY + 150, plate.minY + 92] as [CGFloat] {
    ctx.move(to: CGPoint(x: plate.minX + 70, y: y))
    ctx.addLine(to: CGPoint(x: plate.maxX - 70, y: y))
}
ctx.strokePath()

gc.flushGraphics()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
