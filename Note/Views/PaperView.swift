import SwiftUI

enum PaperTone {
    case light, sepia, dark

    var paper: Color {
        switch self {
        case .light: Color(red: 0.995, green: 0.995, blue: 0.985)
        case .sepia: Color(red: 0.96, green: 0.91, blue: 0.80)
        case .dark: Color(red: 0.11, green: 0.11, blue: 0.125)
        }
    }
    var line: Color {
        switch self {
        case .light: Color(red: 0.55, green: 0.68, blue: 0.86)
        case .sepia: Color(red: 0.72, green: 0.60, blue: 0.42)
        case .dark: Color(red: 0.30, green: 0.34, blue: 0.42)
        }
    }
    var margin: Color {
        switch self {
        case .light: Color(red: 0.90, green: 0.35, blue: 0.38)
        case .sepia: Color(red: 0.78, green: 0.38, blue: 0.30)
        case .dark: Color(red: 0.55, green: 0.25, blue: 0.28)
        }
    }
    var ink: Color {
        switch self {
        case .light: Color(red: 0.08, green: 0.10, blue: 0.20)
        case .sepia: Color(red: 0.22, green: 0.15, blue: 0.08)
        case .dark: Color(white: 0.90)
        }
    }
}

/// Draws the ruling of an A4 sheet. `mm` is the on-screen size of one millimetre;
/// by default the view's width is treated as 210 mm.
struct PaperView: View {
    var style: PaperStyle
    var tone: PaperTone
    var mm: CGFloat? = nil

    var body: some View {
        Canvas { ctx, size in
            let u = mm ?? size.width / 210
            let lw = max(0.5, u * 0.16)
            let w = size.width, h = size.height
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(tone.paper))
            let line = GraphicsContext.Shading.color(tone.line)

            switch style {
            case .blank:
                break

            case .squared:
                var p = Path()
                var x = 5 * u
                while x < w { p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: h)); x += 5 * u }
                var y = 5 * u
                while y < h { p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: w, y: y)); y += 5 * u }
                ctx.stroke(p, with: line, lineWidth: lw)

            case .lined:
                var p = Path()
                var y = 30 * u
                while y < h - 8 * u { p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: w, y: y)); y += 8 * u }
                ctx.stroke(p, with: line, lineWidth: lw)
                var m = Path()
                m.move(to: CGPoint(x: 25 * u, y: 0)); m.addLine(to: CGPoint(x: 25 * u, y: h))
                ctx.stroke(m, with: .color(tone.margin), lineWidth: lw * 1.3)

            case .guide:
                // Handwriting guide: a tinted x-height band between ascender and descender lines, plus slant strokes.
                var solid = Path(), faint = Path(), slant = Path()
                var y = 22 * u
                while y + 11 * u < h - 8 * u {
                    ctx.fill(Path(CGRect(x: 0, y: y + 3.5 * u, width: w, height: 3.5 * u)), with: .color(tone.line.opacity(0.16)))
                    for (i, dy) in [0, 3.5, 7, 10.5].enumerated() {
                        let yy = y + CGFloat(dy) * u
                        if i == 1 || i == 2 {
                            solid.move(to: CGPoint(x: 0, y: yy)); solid.addLine(to: CGPoint(x: w, y: yy))
                        } else {
                            faint.move(to: CGPoint(x: 0, y: yy)); faint.addLine(to: CGPoint(x: w, y: yy))
                        }
                    }
                    var x = 6 * u
                    while x < w + 6 * u {
                        slant.move(to: CGPoint(x: x, y: y)); slant.addLine(to: CGPoint(x: x - 4.2 * u, y: y + 10.5 * u))
                        x += 10 * u
                    }
                    y += 16 * u
                }
                ctx.stroke(solid, with: line, lineWidth: lw * 1.2)
                ctx.stroke(faint, with: .color(tone.line.opacity(0.6)), lineWidth: lw)
                ctx.stroke(slant, with: .color(tone.line.opacity(0.35)), lineWidth: lw)

            case .dotted:
                var p = Path()
                let r = max(0.6, u * 0.3)
                var y = 5 * u
                while y < h {
                    var x = 5 * u
                    while x < w { p.addEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)); x += 5 * u }
                    y += 5 * u
                }
                ctx.fill(p, with: line)

            case .isometric:
                let s = 7 * u
                let k = 1 / sqrt(3.0)
                var p = Path()
                var x = s * sqrt(3.0) / 2
                while x < w { p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: h)); x += s * sqrt(3.0) / 2 }
                var c = -ceil(w * k / s) * s
                while c < h + w * k {
                    p.move(to: CGPoint(x: 0, y: c)); p.addLine(to: CGPoint(x: w, y: c + w * k))
                    p.move(to: CGPoint(x: 0, y: c + w * k)); p.addLine(to: CGPoint(x: w, y: c))
                    c += s
                }
                ctx.stroke(p, with: .color(tone.line.opacity(0.8)), lineWidth: lw)
            }
        }
    }
}

/// Small swatch used in pickers.
struct PaperThumb: View {
    var style: PaperStyle
    var selected = false
    var body: some View {
        PaperView(style: style, tone: .light, mm: 1.5)
            .frame(width: 58, height: 82)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(selected ? Color.accentColor : Color.gray.opacity(0.4), lineWidth: selected ? 3 : 1))
    }
}
