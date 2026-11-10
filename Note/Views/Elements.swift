import SwiftUI
import UIKit

// MARK: Looks

extension ElementColor {
    var color: Color {
        switch self {
        case .yellow: Color(red: 1.0, green: 0.86, blue: 0.30)
        case .pink: Color(red: 1.0, green: 0.55, blue: 0.70)
        case .blue: Color(red: 0.36, green: 0.62, blue: 0.98)
        case .green: Color(red: 0.42, green: 0.80, blue: 0.50)
        case .orange: Color(red: 1.0, green: 0.60, blue: 0.22)
        case .purple: Color(red: 0.66, green: 0.50, blue: 0.94)
        case .red: Color(red: 0.92, green: 0.25, blue: 0.25)
        case .black: Color(white: 0.12)
        }
    }
}

private extension View {
    /// The white rim of a die-cut sticker.
    func dieCut(_ r: CGFloat) -> some View {
        self
            .shadow(color: .white, radius: 0, x: r, y: 0)
            .shadow(color: .white, radius: 0, x: -r, y: 0)
            .shadow(color: .white, radius: 0, x: 0, y: r)
            .shadow(color: .white, radius: 0, x: 0, y: -r)
    }
}

/// How one element looks, drawn at its own width with no position or rotation applied.
struct ElementView: View {
    let element: PageElement
    let tone: PaperTone

    private var w: CGFloat { element.width }
    private var tint: Color { element.color.color }

    var body: some View {
        switch element.kind {
        case .sticker:
            Text(element.symbol)
                .font(.system(size: w * 0.78))
                .dieCut(w * 0.035)
                .frame(width: w, height: w)

        case .label:
            HStack(spacing: w * 0.04) {
                Image(systemName: element.symbol)
                Text(element.text).lineLimit(1).minimumScaleFactor(0.5)
            }
            .font(.system(size: w * 0.13, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, w * 0.07)
            .padding(.vertical, w * 0.05)
            .frame(width: w * 0.94)
            .background(tint, in: Capsule())
            .padding(w * 0.03)
            .background(.white, in: Capsule())

        case .note:
            ZStack(alignment: .topLeading) {
                Rectangle().fill(LinearGradient(colors: [tint.opacity(0.92), tint], startPoint: .top, endPoint: .bottom))
                // The gummed strip along the top edge.
                Rectangle().fill(.black.opacity(0.06)).frame(height: w * 0.12)
                Text(element.text)
                    .font(.custom("Noteworthy-Bold", size: w * 0.105))
                    .foregroundStyle(.black.opacity(0.82))
                    .padding(.horizontal, w * 0.08)
                    .padding(.top, w * 0.17)
                    .padding(.bottom, w * 0.06)
            }
            .frame(width: w, height: w)

        case .tape:
            Canvas { ctx, size in
                var body = Path()
                let tooth = size.height / 5
                body.move(to: .zero)
                body.addLine(to: CGPoint(x: size.width, y: 0))
                var y: CGFloat = 0
                while y < size.height {
                    body.addLine(to: CGPoint(x: size.width - tooth * 0.6, y: y + tooth / 2))
                    body.addLine(to: CGPoint(x: size.width, y: y + tooth))
                    y += tooth
                }
                body.addLine(to: CGPoint(x: 0, y: size.height))
                y = size.height
                while y > 0 {
                    body.addLine(to: CGPoint(x: tooth * 0.6, y: y - tooth / 2))
                    body.addLine(to: CGPoint(x: 0, y: y - tooth))
                    y -= tooth
                }
                body.closeSubpath()
                ctx.fill(body, with: .color(tint.opacity(0.72)))
                ctx.clip(to: body)
                var x = -size.height
                while x < size.width {
                    var stripe = Path()
                    stripe.move(to: CGPoint(x: x, y: size.height))
                    stripe.addLine(to: CGPoint(x: x + size.height, y: 0))
                    ctx.stroke(stripe, with: .color(.white.opacity(0.4)), lineWidth: size.height * 0.16)
                    x += size.height * 0.55
                }
            }
            .frame(width: w, height: w * 0.17)

        case .text:
            styledText.frame(width: w)

        case .shape:
            Image(systemName: element.symbol)
                .resizable()
                .scaledToFit()
                .fontWeight(.light)
                .foregroundStyle(element.color == .black ? tone.ink : tint)
                .frame(width: w, height: w)
        }
    }

    @ViewBuilder private var styledText: some View {
        let ink = element.color == .black ? tone.ink : tint
        let text = element.text.isEmpty ? " " : element.text
        switch element.style {
        case .title:
            Text(text).font(.system(size: w * 0.15, weight: .black, design: .serif))
                .foregroundStyle(ink).multilineTextAlignment(.center)
        case .marker:
            Text(text).font(.system(size: w * 0.11, weight: .bold, design: .rounded))
                .foregroundStyle(.black.opacity(0.85))
                .padding(.horizontal, w * 0.03)
                .background((element.color == .black ? ElementColor.yellow.color : tint).opacity(0.6))
        case .typewriter:
            Text(text).font(.system(size: w * 0.085, weight: .regular, design: .monospaced))
                .foregroundStyle(ink).frame(maxWidth: .infinity, alignment: .leading)
        case .script:
            Text(text).font(.custom("SnellRoundhand-Bold", size: w * 0.15))
                .foregroundStyle(ink).multilineTextAlignment(.center)
        case .bubble:
            Text(text).font(.system(size: w * 0.095, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(w * 0.06)
                .frame(maxWidth: .infinity)
                .background(element.color == .black ? Color(white: 0.15) : tint, in: RoundedRectangle(cornerRadius: w * 0.07))
        }
    }
}

// MARK: Static layer (reading, drawing, export)

struct StaticElements: View {
    let elements: [PageElement]
    let tone: PaperTone

    var body: some View {
        ZStack {
            Color.clear
            ForEach(elements) { e in
                ElementView(element: e, tone: tone)
                    .rotationEffect(.degrees(e.rotation))
                    .shadow(color: .black.opacity(e.kind.isPhysical ? 0.2 : 0), radius: 2.5, x: 1, y: 2)
                    .position(x: e.x, y: e.y)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: Interactive layer (sticker mode)

struct ElementsLayer: View {
    let pageID: UUID
    let elements: [PageElement]
    let tone: PaperTone
    @Environment(EditorState.self) private var editor

    var body: some View {
        ZStack {
            // Tapping bare paper lets go of the selection.
            Color.clear.contentShape(Rectangle()).onTapGesture { editor.selectedElement = nil }
            ForEach(elements) { e in
                StickableElement(element: e, pageID: pageID, tone: tone)
            }
        }
        .coordinateSpace(.named("sheet"))
    }
}

/// One element you can pick up, move, turn, resize and press back onto the paper.
private struct StickableElement: View {
    let element: PageElement
    let pageID: UUID
    let tone: PaperTone
    @Environment(NoteStore.self) private var store
    @Environment(EditorState.self) private var editor
    @State private var drag = CGSize.zero
    @State private var lifted = false
    @State private var pressed = false
    @State private var liveScale: CGFloat = 1
    @State private var liveAngle: Double = 0
    @State private var grabStart: CGPoint?

    private var selected: Bool { editor.selectedElement == element.id }
    private var center: CGPoint { CGPoint(x: element.x, y: element.y) }

    var body: some View {
        ElementView(element: element, tone: tone)
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [10, 7]))
                        .padding(-10)
                }
            }
            .overlay(alignment: .bottomTrailing) { if selected { handle.offset(x: 34, y: 34) } }
            // Peeled up: bigger, tilted toward you, shadow far below. Pressed: a brief squash.
            .scaleEffect(liveScale * (lifted ? 1.12 : (pressed ? 0.95 : 1)))
            .rotation3DEffect(.degrees(lifted ? 16 : 0), axis: (x: 1, y: -0.5, z: 0), perspective: 0.5)
            .rotationEffect(.degrees(element.rotation + liveAngle))
            .shadow(color: .black.opacity(lifted ? 0.32 : (element.kind.isPhysical ? 0.2 : 0)),
                    radius: lifted ? 24 : 2.5, x: lifted ? 12 : 1, y: lifted ? 30 : 2)
            .position(x: element.x + drag.width, y: element.y + drag.height)
            .gesture(move)
            .onTapGesture {
                editor.selectedElement = element.id
                Haptics.tap()
            }
            .zIndex(lifted || selected ? 1 : 0)
            .onAppear {
                // A new sticker arrives held above the page, then gets pressed on.
                guard editor.justAdded == element.id else { return }
                editor.justAdded = nil
                lifted = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { stick() }
            }
    }

    private var handle: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 60, height: 60)
            .background(Color.accentColor, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 3))
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("sheet"))
                .onChanged { value in
                    let start = grabStart ?? value.startLocation
                    grabStart = start
                    let a = CGVector(dx: start.x - center.x, dy: start.y - center.y)
                    let b = CGVector(dx: value.location.x - center.x, dy: value.location.y - center.y)
                    let la = max(1, hypot(a.dx, a.dy)), lb = hypot(b.dx, b.dy)
                    liveScale = min(max(lb / la, 40 / element.width), 1600 / element.width)
                    liveAngle = (atan2(b.dy, b.dx) - atan2(a.dy, a.dx)) * 180 / .pi
                }
                .onEnded { _ in
                    var e = element
                    e.width *= liveScale
                    e.rotation += liveAngle
                    liveScale = 1
                    liveAngle = 0
                    grabStart = nil
                    store.updateElement(e, on: pageID)
                    Haptics.stick()
                })
    }

    private var move: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("sheet"))
            .onChanged { value in
                if !lifted {
                    editor.selectedElement = element.id
                    Haptics.lift()
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { lifted = true }
                }
                drag = value.translation
            }
            .onEnded { value in
                var e = element
                e.x += value.translation.width
                e.y += value.translation.height
                drag = .zero
                store.updateElement(e, on: pageID)
                stick()
            }
    }

    /// Slap it down: drop fast, squash for an instant, settle.
    private func stick() {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
            lifted = false
            pressed = true
        }
        Haptics.stick()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { pressed = false }
        }
    }
}

// MARK: Drawer

/// The sticker book: everything that can be put on a page.
struct StickerDrawer: View {
    var onPick: (PageElement) -> Void
    @Environment(\.dismiss) private var dismiss

    private static let emoji = ["⭐️", "✅", "❗️", "❓", "💡", "📌", "📎", "🔥", "❤️", "👍", "🎯", "⏰",
                                "📅", "✏️", "📚", "☕️", "🎉", "🚀", "🌈", "🍀", "👀", "💬", "🧠", "🏆"]
    private static let shapes = ["rectangle", "circle", "triangle", "star", "heart", "arrow.right", "arrow.turn.down.right", "bubble.left"]
    private static let palette: [ElementColor] = [.yellow, .pink, .blue, .green]

    private var labels: [PageElement] {
        [
            PageElement(kind: .label, width: 300, symbol: "checkmark.circle.fill", text: String(localized: "TO DO"), color: .blue),
            PageElement(kind: .label, width: 340, symbol: "exclamationmark.triangle.fill", text: String(localized: "IMPORTANT"), color: .red),
            PageElement(kind: .label, width: 260, symbol: "lightbulb.fill", text: String(localized: "IDEA"), color: .orange),
            PageElement(kind: .label, width: 260, symbol: "checkmark.seal.fill", text: String(localized: "DONE"), color: .green),
            PageElement(kind: .label, width: 320, symbol: "questionmark.circle.fill", text: String(localized: "QUESTION"), color: .purple),
            PageElement(kind: .label, width: 320, symbol: "clock.fill", text: String(localized: "DEADLINE"), color: .black),
            PageElement(kind: .label, width: 340, symbol: "calendar", text: Date().formatted(date: .abbreviated, time: .omitted), color: .black),
        ]
    }

    private var texts: [PageElement] {
        ElementTextStyle.allCases.map {
            PageElement(kind: .text, width: 440, text: $0.title, style: $0, color: $0 == .marker ? .yellow : ($0 == .bubble ? .blue : .black))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    group("Stickers") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 10)], spacing: 10) {
                            ForEach(Self.emoji, id: \.self) { e in
                                tile(PageElement(kind: .sticker, width: 150, symbol: e), size: 52)
                            }
                        }
                    }
                    group("Labels") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                            ForEach(labels) { tile($0, size: 120) }
                        }
                    }
                    group("Sticky notes & tape") {
                        HStack(spacing: 14) {
                            ForEach(Self.palette, id: \.self) { c in
                                tile(PageElement(kind: .note, width: 320, color: c), size: 62)
                            }
                        }
                        HStack(spacing: 14) {
                            ForEach(Self.palette, id: \.self) { c in
                                tile(PageElement(kind: .tape, width: 380, color: c), size: 70)
                            }
                        }
                    }
                    group("Styled text") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 14) {
                            ForEach(texts) { tile($0, size: 124) }
                        }
                    }
                    group("Shapes") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 10)], spacing: 10) {
                            ForEach(Self.shapes, id: \.self) { s in
                                tile(PageElement(kind: .shape, width: 220, symbol: s), size: 46)
                            }
                        }
                    }
                }
                .padding(18)
            }
            .navigationTitle("Stickers & Objects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func group<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
    }

    /// A preview of the element, scaled down to `size` points wide.
    private func tile(_ element: PageElement, size: CGFloat) -> some View {
        let k = size / element.width
        return Button {
            onPick(element)
            dismiss()
        } label: {
            ElementView(element: element, tone: .light)
                .scaleEffect(k)
                .frame(width: size, height: max(34, previewHeight(element) * k))
                .shadow(color: .black.opacity(element.kind.isPhysical ? 0.18 : 0), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func previewHeight(_ e: PageElement) -> CGFloat {
        switch e.kind {
        case .sticker, .note, .shape: e.width
        case .label: e.width * 0.3
        case .tape: e.width * 0.17
        case .text: e.width * 0.28
        }
    }
}

/// Edit the words on a sticky note, label or text box.
struct ElementTextEditor: View {
    @State var text: String
    var onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .focused($focused)
                .font(.title3)
                .padding()
                .navigationTitle("Text")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            onSave(text)
                            dismiss()
                        }
                    }
                }
                .onAppear { focused = true }
        }
        .presentationDetents([.medium])
    }
}
