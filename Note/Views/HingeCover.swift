import SwiftUI

/// Foldable support: while the device is folded shut the screen shows the cover of the
/// notebook you are in (its own colour, pattern or photo), and as the hinge opens the
/// cover swings away with it, like opening the real book.
struct HingeCover: ViewModifier {
    @Environment(NoteStore.self) private var store
    @Environment(AppSettings.self) private var settings
    /// 0 = folded shut, 1 = fully open, nil = no hinge on this device.
    @State private var openness: Double?
    /// The cover was tapped open; it comes back the next time the device is folded shut.
    @State private var opened = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if settings.foldCover, !opened, let openness, openness < 0.7,
                   let nb = store.activeNotebookID.flatMap(store.notebook) ?? store.mostRecentNotebook {
                    ClosedBook(notebook: nb, openness: openness, open: open) { action in
                        Router.shared.pending = action
                        open()
                    }
                    .onTapGesture(perform: open)
                    .onAppear { store.coverUp = true }
                    .onDisappear { store.coverUp = false }
                        .transition(.asymmetric(insertion: .opacity, removal: .modifier(
                            active: CoverSwing(angle: -100), identity: CoverSwing(angle: 0))))
                }
            }
            .onChange(of: openness) { old, new in
                // Folding shut closes the book again; opening the hinge needs no tap.
                if new == 0, old != 0 { opened = false }
                if let new, new >= 0.7 { opened = false }
            }
            .modifier(HingeWatcher(openness: $openness))
    }

    private func open() {
        Haptics.tap()
        withAnimation(.easeIn(duration: 0.45)) { opened = true }
    }
}

private struct HingeWatcher: ViewModifier {
    @Binding var openness: Double?

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content
                .onHingeChange { _, context in
                    let value: Double?
                    if let hinge = context.hinge {
                        if hinge.status == .closed {
                            value = 0
                        } else if hinge.status == .fullyOpen {
                            value = 1
                        } else {
                            value = min(1, max(0.02, hinge.angle.degrees / 180))
                        }
                    } else {
                        value = nil
                    }
                    withAnimation(.smooth(duration: 0.25)) { openness = value }
                }
                .onAppear(perform: debugOverride)
        } else {
            content
        }
    }

    /// Simulators without a hinge control can preview a pose: NOTE_FAKE_HINGE=0…1.
    private func debugOverride() {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["NOTE_FAKE_HINGE"], let value = Double(raw) {
            openness = value
        }
        #endif
    }
}

/// The cover turning on its spine.
private struct CoverSwing: ViewModifier {
    let angle: Double
    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.4)
            .opacity(angle == 0 ? 1 : 0)
    }
}

private struct ClosedBook: View {
    let notebook: Notebook
    let openness: Double
    var open: () -> Void = {}
    var perform: (Router.Action) -> Void = { _ in }

    var body: some View {
        // Folded shut, the cover fills the whole screen. As the hinge opens it swings
        // away around the spine and thins out, revealing the page underneath.
        CoverView(notebook, fill: true)
            .rotation3DEffect(.degrees(-openness * 100), axis: (x: 0, y: 1, z: 0),
                              anchor: .leading, perspective: 0.4)
            .opacity(openness < 0.25 ? 1 : max(0, 1 - (openness - 0.25) / 0.45))
            .overlay(alignment: .bottom) {
                if openness == 0 {
                    // What you can do straight from the closed book.
                    HStack(spacing: 10) {
                        coverButton("Open", "book.pages", prominent: true, action: open)
                        coverButton("Quick Note", "bolt.fill") { perform(.quickNote) }
                        coverButton("Change Cover", "paintpalette") { perform(.editCover(notebook.id)) }
                    }
                    .padding(8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 26)
                    .padding(.horizontal, 12)
                }
            }
            .contentShape(Rectangle())
        .ignoresSafeArea()
        .allowsHitTesting(openness < 0.5)
        .accessibilityLabel(Text(notebook.title))
    }

    private func coverButton(_ title: LocalizedStringKey, _ symbol: String, prominent: Bool = false,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .foregroundStyle(prominent ? Color.black : Color.white)
                .background(prominent ? Color.white : Color.white.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
