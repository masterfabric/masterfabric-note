import PencilKit
import SwiftUI

enum EditorMode: String, CaseIterable, Identifiable {
    case read, draw, type, stick
    var id: String { rawValue }
    var title: String {
        switch self {
        case .read: String(localized: "Read")
        case .draw: String(localized: "Draw")
        case .type: String(localized: "Type")
        case .stick: String(localized: "Stickers")
        }
    }
    var symbol: String {
        switch self {
        case .read: "book"
        case .draw: "pencil.tip"
        case .type: "keyboard"
        case .stick: "face.smiling"
        }
    }
}

@MainActor
@Observable
final class EditorState {
    var mode: EditorMode = .draw
    var currentPageID: UUID?
    var selectedElement: UUID?
    /// Set when an element is created so it arrives with the stick-on animation.
    var justAdded: UUID?
}

/// One sheet: ruling, typed text and the PencilKit layer, laid out at the canonical
/// A4 size and scaled to fit, so a page looks the same on every device.
struct PageView: View {
    let notebookID: UUID
    let pageID: UUID
    @Environment(NoteStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(EditorState.self) private var editor
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        // The sheet covers the whole screen, edge to edge. The A4 area always fits;
        // on screens with another shape the ruling simply continues past it.
        GeometryReader { outer in
            let insets = outer.safeAreaInsets
            GeometryReader { geo in
                sheet(size: geo.size, insets: insets)
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func sheet(size: CGSize, insets: EdgeInsets) -> some View {
            let s = max(0.05, min(size.width / PageMetrics.width, size.height / PageMetrics.height))
            if let page = store.page(notebookID, pageID) {
                let tone = settings.tone(for: scheme)
                ZStack(alignment: .topLeading) {
                    ZStack {
                        PaperView(style: page.paper, tone: tone, mm: PageMetrics.width / 210)
                        PageTextLayer(page: page, tone: tone, editing: editor.mode == .type,
                                      top: max(96, insets.top / s + 24), bottom: max(48, insets.bottom / s + 24)) { store.setText($0, page: pageID) }
                        if editor.mode == .stick {
                            ElementsLayer(pageID: pageID, elements: page.elements, tone: tone)
                        } else {
                            StaticElements(elements: page.elements, tone: tone)
                        }
                    }
                    .frame(width: size.width / s, height: size.height / s)
                    .scaleEffect(s, anchor: .topLeading)
                    .frame(width: size.width, height: size.height, alignment: .topLeading)

                    // The canvas is laid out at screen size and zooms its own content,
                    // so PencilKit renders every tile at native resolution.
                    CanvasView(pageID: pageID, store: store, scale: s,
                               revision: store.revisions[pageID] ?? 0,
                               drawingEnabled: editor.mode == .draw,
                               pencilOnly: settings.pencilOnly,
                               active: editor.mode == .draw && editor.currentPageID == pageID && !store.coverUp)
                        .allowsHitTesting(editor.mode == .draw)
                        .frame(width: size.width, height: size.height)
                }
                .clipped()
            }
    }
}

struct PageTextLayer: View {
    let page: Page
    let tone: PaperTone
    var editing = false
    var top: CGFloat = 96
    var bottom: CGFloat = 48
    var onChange: (String) -> Void = { _ in }

    private var leading: CGFloat { page.paper == .lined ? 112 : 60 }

    var body: some View {
        Group {
            if editing {
                TextEditor(text: Binding(get: { page.text }, set: onChange))
                    .scrollContentBackground(.hidden)
            } else {
                Text(page.text)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 5)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }
        }
        .font(.system(size: 30))
        .lineSpacing(6)
        .foregroundStyle(tone.ink)
        .padding(.leading, leading)
        .padding(.trailing, 48)
        .padding(.top, top)
        .padding(.bottom, bottom)
    }
}

/// One tool picker for the whole app so the chosen pen follows you from page to page.
@MainActor
enum ToolPicker {
    static let shared = PKToolPicker()
}

/// A plain 1:1 canvas covering the sheet. Drawings are stored in canonical sheet points and
/// scaled by `pageScale` on the way in and out, so PencilKit never has to zoom or be
/// transformed (both leave parts of the canvas unrendered).
final class SheetCanvas: PKCanvasView {
    var pageScale: CGFloat = 1 { didSet { if pageScale != oldValue { setNeedsLayout() } } }
    private var configured: (size: CGSize, scale: CGFloat) = (.zero, 0)
    /// Called once the sheet has its real size, and again whenever size or scale change.
    var onConfigured: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, pageScale > 0 else { return }
        if contentSize != bounds.size { contentSize = bounds.size }
        if contentOffset != .zero { contentOffset = .zero }
        if configured.size != bounds.size || abs(configured.scale - pageScale) > 0.0001 {
            configured = (bounds.size, pageScale)
            DispatchQueue.main.async { [weak self] in self?.onConfigured?() }
        }
    }
}

struct CanvasView: UIViewRepresentable {
    let pageID: UUID
    let store: NoteStore
    var scale: CGFloat
    var revision: Int
    var drawingEnabled: Bool
    var pencilOnly: Bool
    var active: Bool

    func makeCoordinator() -> Coordinator { Coordinator(pageID: pageID, store: store) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = SheetCanvas()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isScrollEnabled = false
        canvas.pageScale = scale
        canvas.contentInsetAdjustmentBehavior = .never
        // The sheet is not scrolling content: keep the bars from fading or tinting it.
        if #available(iOS 26.0, *) {
            canvas.topEdgeEffect.isHidden = true
            canvas.bottomEdgeEffect.isHidden = true
            canvas.leftEdgeEffect.isHidden = true
            canvas.rightEdgeEffect.isHidden = true
        }
        let coordinator = context.coordinator
        canvas.onConfigured = { [weak canvas, weak coordinator] in
            guard let canvas, let coordinator else { return }
            coordinator.load(into: canvas)
        }
        canvas.tool = PKInkingTool(.pen, color: .black, width: 5)
        canvas.delegate = context.coordinator
        ToolPicker.shared.addObserver(canvas)
        context.coordinator.revision = revision
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        let c = context.coordinator
        (canvas as? SheetCanvas)?.pageScale = scale
        canvas.drawingPolicy = pencilOnly ? .pencilOnly : .anyInput
        canvas.isUserInteractionEnabled = drawingEnabled
        if c.revision != revision {
            c.revision = revision
            c.load(into: canvas)
        }
        if c.active != active {
            c.active = active
            if active {
                c.activate(canvas, tries: 6)
            } else {
                ToolPicker.shared.setVisible(false, forFirstResponder: canvas)
                if canvas.isFirstResponder { canvas.resignFirstResponder() }
            }
        }
    }

    static func dismantleUIView(_ canvas: PKCanvasView, coordinator: Coordinator) {
        ToolPicker.shared.removeObserver(canvas)
    }

    @MainActor
    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let pageID: UUID
        let store: NoteStore
        var revision = 0
        var loading = false
        var active = false

        init(pageID: UUID, store: NoteStore) {
            self.pageID = pageID
            self.store = store
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !loading, let scale = (canvasView as? SheetCanvas)?.pageScale, scale > 0 else { return }
            store.saveDrawing(canvasView.drawing.transformed(using: CGAffineTransform(scaleX: 1 / scale, y: 1 / scale)), for: pageID)
        }

        /// Shows the stored drawing at the canvas's current scale.
        func load(into canvas: PKCanvasView) {
            let scale = (canvas as? SheetCanvas)?.pageScale ?? 1
            loading = true
            canvas.drawing = store.drawing(for: pageID).transformed(using: CGAffineTransform(scaleX: scale, y: scale))
            DispatchQueue.main.async { self.loading = false }
        }

        /// The canvas may not be in a window yet while a page transition is running.
        func activate(_ canvas: PKCanvasView, tries: Int) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self, weak canvas] in
                guard let self, let canvas, self.active else { return }
                if canvas.window == nil {
                    if tries > 0 { self.activate(canvas, tries: tries - 1) }
                    return
                }
                ToolPicker.shared.setVisible(true, forFirstResponder: canvas)
                canvas.becomeFirstResponder()
            }
        }
    }
}
