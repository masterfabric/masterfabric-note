import SwiftUI
import UIKit

/// A composition-book cover: black spine, patterned board, white label plate.
struct CoverView: View {
    var title: String
    var color: CoverColor
    var art: CoverArt
    var seed: UInt64
    var photo: UIImage? = nil
    var footer: String = ""

    /// Stretch over whatever space is offered (the folded-phone cover) instead of keeping A4 proportions.
    var fill = false

    var body: some View {
        if fill { board } else { board.aspectRatio(210.0 / 297.0, contentMode: .fit) }
    }

    private var board: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            // `u` is the width of an A4 cover that fits here; every detail is sized from it.
            let u = min(w, h * 210.0 / 297.0)
            ZStack(alignment: .leading) {
                artwork
                Rectangle()
                    .fill(LinearGradient(colors: [Color(white: 0.02), Color(white: 0.13), Color(white: 0.03)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: u * 0.09)
                label(w: u)
                    .frame(width: u * 0.58, height: u * 0.297)
                    .position(x: u * 0.09 + (w - u * 0.09) / 2, y: h * (fill ? 0.36 : 0.29))
            }
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: fill ? 0 : u * 0.012, bottomLeadingRadius: fill ? 0 : u * 0.012,
                                              bottomTrailingRadius: fill ? 0 : u * 0.05, topTrailingRadius: fill ? 0 : u * 0.05))
        }
    }

    private func label(w: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: w * 0.05).fill(.white)
            RoundedRectangle(cornerRadius: w * 0.038)
                .inset(by: w * 0.014)
                .stroke(.black, lineWidth: w * 0.009)
            VStack(spacing: w * 0.022) {
                Text(title.uppercased())
                    .font(.system(size: w * 0.052, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle().frame(height: max(0.5, w * 0.004))
                }
                Text(footer)
                    .font(.system(size: w * 0.027, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
            }
            .foregroundStyle(.black)
            .padding(.horizontal, w * 0.045)
            .padding(.vertical, w * 0.03)
        }
    }

    @ViewBuilder private var artwork: some View {
        if art == .photo, let photo {
            Color.clear.overlay(Image(uiImage: photo).resizable().scaledToFill()).clipped()
        } else {
            Canvas { ctx, size in
                var rng = SeededRandom(seed: seed)
                let base = color.color
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(base))
                switch art {
                case .marble, .photo: Self.marble(&ctx, size, &rng)
                case .waves: Self.waves(&ctx, size, &rng)
                case .rings: Self.rings(&ctx, size, &rng)
                case .mosaic: Self.mosaic(&ctx, size, &rng)
                }
            }
        }
    }

    // MARK: Patterns

    /// The classic speckle: hundreds of small irregular white blots.
    private static func marble(_ ctx: inout GraphicsContext, _ size: CGSize, _ rng: inout SeededRandom) {
        var path = Path()
        let w = size.width, h = size.height
        let u = min(w, h * 210.0 / 297.0)
        let count = Int(620 * (w * h) / (u * u * 297.0 / 210.0))
        for _ in 0..<min(count, 4000) {
            let cx = CGFloat.random(in: 0...w, using: &rng)
            let cy = CGFloat.random(in: 0...h, using: &rng)
            let r = u * CGFloat.random(in: 0.006...0.017, using: &rng)
            for _ in 0..<Int.random(in: 2...4, using: &rng) {
                let ox = CGFloat.random(in: -r...r, using: &rng) * 1.3
                let oy = CGFloat.random(in: -r...r, using: &rng) * 1.3
                let rx = r * CGFloat.random(in: 0.5...1.25, using: &rng)
                let ry = r * CGFloat.random(in: 0.4...1.0, using: &rng)
                let angle = CGFloat.random(in: 0...(.pi), using: &rng)
                let t = CGAffineTransform(translationX: cx + ox, y: cy + oy).rotated(by: angle)
                path.addPath(Path(ellipseIn: CGRect(x: -rx, y: -ry, width: 2 * rx, height: 2 * ry)), transform: t)
            }
        }
        ctx.fill(path, with: .color(.white))
    }

    private static func waves(_ ctx: inout GraphicsContext, _ size: CGSize, _ rng: inout SeededRandom) {
        let w = size.width, h = size.height
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(Gradient(colors: [.white.opacity(0.22), .black.opacity(0.35)]),
                                       startPoint: .zero, endPoint: CGPoint(x: w, y: h)))
        for i in 0..<9 {
            let baseY = h * (0.08 + CGFloat(i) * 0.11)
            let amp = h * CGFloat.random(in: 0.02...0.06, using: &rng)
            let freq = CGFloat.random(in: 1.0...2.4, using: &rng)
            let phase = CGFloat.random(in: 0...(2 * .pi), using: &rng)
            var p = Path()
            p.move(to: CGPoint(x: 0, y: h))
            var x: CGFloat = 0
            while x <= w {
                p.addLine(to: CGPoint(x: x, y: baseY + sin(x / w * freq * 2 * .pi + phase) * amp))
                x += max(1, w / 60)
            }
            p.addLine(to: CGPoint(x: w, y: h))
            p.closeSubpath()
            ctx.fill(p, with: .color(.white.opacity(i % 2 == 0 ? 0.13 : 0.07)))
        }
    }

    private static func rings(_ ctx: inout GraphicsContext, _ size: CGSize, _ rng: inout SeededRandom) {
        let w = size.width, h = size.height
        for _ in 0..<3 {
            let c = CGPoint(x: CGFloat.random(in: 0.15...1.0, using: &rng) * w, y: CGFloat.random(in: 0.1...1.0, using: &rng) * h)
            let step = w * CGFloat.random(in: 0.05...0.08, using: &rng)
            for i in 1...9 {
                let r = step * CGFloat(i)
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                           with: .color(.white.opacity(0.42 - Double(i) * 0.035)), lineWidth: step * 0.34)
            }
        }
    }

    private static func mosaic(_ ctx: inout GraphicsContext, _ size: CGSize, _ rng: inout SeededRandom) {
        let w = size.width, h = size.height
        let cols = 7
        let s = w / CGFloat(cols)
        let rows = Int(ceil(h / s))
        for row in 0..<rows {
            for col in 0..<cols {
                let rect = CGRect(x: CGFloat(col) * s, y: CGFloat(row) * s, width: s, height: s)
                let flip = Bool.random(using: &rng)
                for half in 0..<2 {
                    var p = Path()
                    if flip {
                        p.move(to: CGPoint(x: rect.minX, y: rect.minY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                        p.addLine(to: half == 0 ? CGPoint(x: rect.minX, y: rect.maxY) : CGPoint(x: rect.maxX, y: rect.maxY))
                        if half == 1 { p = Path(); p.move(to: CGPoint(x: rect.maxX, y: rect.minY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY)) }
                    } else {
                        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
                        if half == 0 { p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY)) }
                        else { p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY)) }
                    }
                    p.closeSubpath()
                    let shade = Double.random(in: 0...1, using: &rng)
                    ctx.fill(p, with: .color(shade > 0.5 ? .white.opacity((shade - 0.5) * 0.7) : .black.opacity((0.5 - shade) * 0.6)))
                }
            }
        }
    }
}

extension CoverView {
    @MainActor
    init(_ nb: Notebook, fill: Bool = false) {
        self.init(title: nb.title, color: nb.color, art: nb.art, seed: nb.seed,
                  photo: nb.art == .photo ? NoteStore.shared.coverPhoto(nb.id) : nil,
                  footer: Self.footer(for: nb), fill: fill)
    }

    static func footer(for nb: Notebook) -> String {
        String(localized: "\(nb.pages.count) pages · A4 · \(nb.paper.title)")
    }
}
