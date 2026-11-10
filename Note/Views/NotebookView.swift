import SwiftUI

struct NotebookView: View {
    let notebookID: UUID
    @Environment(NoteStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @State private var editor = EditorState()
    @State private var index = 0
    @State private var ready = false
    @State private var showPages = false
    @State private var share: ShareItems?
    @State private var busy = false
    @State private var confirmClear = false
    @State private var confirmDelete = false
    @State private var showDrawer = false
    @State private var editingText: PageElement?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let nb = store.notebook(notebookID) {
            let safeIndex = min(max(index, 0), nb.pages.count - 1)
            let page = nb.pages[safeIndex]
            PagePager(pageIDs: nb.pages.map(\.id), index: $index, style: settings.turnStyle,
                      gesturesEnabled: editor.mode == .read || (editor.mode == .draw && settings.pencilOnly)) { pageID in
                AnyView(PageView(notebookID: notebookID, pageID: pageID)
                    .environment(store).environment(settings).environment(editor))
            }
            .id(settings.turnStyle)
            .ignoresSafeArea()
            .background(Desk.color)
            .overlay { if busy { ProgressView().controlSize(.large).padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14)) } }
            .navigationBarTitleDisplayMode(.inline)
            // Back is a button only: a swipe-to-go-back gesture would fight with drawing.
            .navigationBarBackButtonHidden(true)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Label("Notebooks", systemImage: "chevron.backward") }
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 4) {
                        Button { go(safeIndex - 1) } label: { Image(systemName: "chevron.left") }
                            .disabled(safeIndex == 0)
                            .keyboardShortcut(.leftArrow, modifiers: .command)
                            .accessibilityLabel("Previous page")
                        Button { showPages = true } label: {
                            Text(verbatim: "\(safeIndex + 1) / \(nb.pages.count)")
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                                .frame(minWidth: 54)
                        }
                        .accessibilityLabel("Pages")
                        Button { go(safeIndex + 1) } label: { Image(systemName: "chevron.right") }
                            .disabled(safeIndex >= nb.pages.count - 1)
                            .keyboardShortcut(.rightArrow, modifiers: .command)
                            .accessibilityLabel("Next page")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Picker("Mode", selection: Binding(get: { editor.mode }, set: { editor.mode = $0; Haptics.tap() })) {
                            ForEach(EditorMode.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                        }
                    } label: { Label("Mode", systemImage: editor.mode.symbol) }

                    Menu {
                        ForEach(PaperStyle.allCases) { style in
                            Button { addPage(after: safeIndex, paper: style) } label: { Label(style.title, systemImage: style.symbol) }
                        }
                    } label: { Label("Add Page", systemImage: "plus") } primaryAction: { addPage(after: safeIndex, paper: nil) }
                        .keyboardShortcut("n", modifiers: .command)

                    Menu {
                        Section {
                            Button { share = ShareItems(items: [Exporter.image(page)]) } label: { Label("Share Page", systemImage: "square.and.arrow.up") }
                            Button { share = ShareItems(items: [Exporter.pdf(nb)]) } label: { Label("Share Notebook as PDF", systemImage: "doc.richtext") }
                        }
                        Section("AI agents") {
                            Button { ask(.summarize, nb, page, safeIndex) } label: { Label("Summarize with an Agent", systemImage: "sparkles") }
                            Button { ask(.todo, nb, page, safeIndex) } label: { Label("Turn into To-Do List", systemImage: "checklist") }
                            Button { ask(.clean, nb, page, safeIndex) } label: { Label("Clean Up My Notes", systemImage: "wand.and.stars") }
                            Button { copyText(page) } label: { Label("Copy Handwriting as Text", systemImage: "text.viewfinder") }
                        }
                        Section {
                            Picker(selection: Binding(get: { page.paper }, set: { store.setPaper($0, page: page.id) })) {
                                ForEach(PaperStyle.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                            } label: { Label("Paper", systemImage: "doc.plaintext") }
                            .pickerStyle(.menu)
                            Button { editor.mode = .stick; showDrawer = true } label: { Label("Stickers & Objects", systemImage: "face.smiling") }
                            Button { showPages = true } label: { Label("All Pages", systemImage: "square.grid.2x2") }
                            Button { store.duplicatePage(page.id, in: notebookID) } label: { Label("Duplicate Page", systemImage: "plus.square.on.square") }
                            Button(role: .destructive) { confirmClear = true } label: { Label("Clear Drawing", systemImage: "eraser") }
                            Button(role: .destructive) { confirmDelete = true } label: { Label("Delete Page", systemImage: "trash") }
                        }
                    } label: { Label("Actions", systemImage: "ellipsis.circle") }
                }
            }
            .overlay(alignment: .bottom) {
                if editor.mode == .stick { stickerBar(page).padding(.bottom, 10) }
            }
            .sheet(isPresented: $showDrawer) {
                StickerDrawer { template in place(template, on: page) }
            }
            .sheet(item: $editingText) { element in
                ElementTextEditor(text: element.text) { text in
                    var e = element
                    e.text = text
                    store.updateElement(e, on: page.id)
                }
            }
            .onChange(of: editor.mode) { _, mode in if mode != .stick { editor.selectedElement = nil } }
            .sheet(isPresented: $showPages) { PageGrid(notebookID: notebookID, index: $index) }
            .sheet(item: $share) { ActivityView(items: $0.items) }
            .confirmationDialog("Clear all drawing on this page?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear Drawing", role: .destructive) { store.clearDrawing(page.id) }
            }
            .confirmationDialog("Delete this page?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete Page", role: .destructive) {
                    store.deletePage(page.id, in: notebookID)
                    index = max(0, safeIndex - 1)
                }
            }
            .onAppear {
                guard !ready else { return }
                ready = true
                index = min(nb.lastIndex, nb.pages.count - 1)
                editor.mode = settings.openInReading ? .read : .draw
                editor.currentPageID = nb.pages[index].id
                store.activeNotebookID = notebookID
            }
            .onChange(of: page.id) { _, id in editor.currentPageID = id }
            .onChange(of: index) { _, i in store.setLastIndex(i, in: notebookID) }
            .onDisappear {
                editor.currentPageID = nil
                if store.activeNotebookID == notebookID { store.activeNotebookID = nil }
            }
        } else {
            ContentUnavailableView("Notebook not found", systemImage: "book.closed")
        }
    }

    /// Controls for sticker mode: add something, or change the selected element.
    @ViewBuilder
    private func stickerBar(_ page: Page) -> some View {
        let selected = page.elements.first { $0.id == editor.selectedElement }
        HStack(spacing: 14) {
            Button { showDrawer = true } label: { Label("Add", systemImage: "plus.circle.fill").labelStyle(.titleAndIcon) }
                .font(.headline)
            if let selected {
                Divider().frame(height: 22)
                if selected.kind != .sticker {
                    Menu {
                        ForEach(ElementColor.allCases, id: \.self) { c in
                            Button {
                                var e = selected
                                e.color = c
                                store.updateElement(e, on: page.id)
                            } label: { Label(c.rawValue.capitalized, systemImage: "circle.fill").tint(c.color) }
                        }
                    } label: { Image(systemName: "paintpalette") }
                        .accessibilityLabel("Color")
                }
                if selected.kind.hasText {
                    Button { editingText = selected } label: { Image(systemName: "character.cursor.ibeam") }
                        .accessibilityLabel("Edit Text")
                }
                Button { store.bringElementToFront(selected.id, on: page.id) } label: { Image(systemName: "square.3.layers.3d.top.filled") }
                    .accessibilityLabel("Bring to Front")
                Button(role: .destructive) {
                    store.removeElement(selected.id, from: page.id)
                    editor.selectedElement = nil
                    Haptics.lift()
                } label: { Image(systemName: "trash") }
                    .accessibilityLabel("Delete")
            }
        }
        .font(.title3)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
    }

    /// Puts a new element near the top middle of the page, slightly askew like a hand would.
    private func place(_ template: PageElement, on page: Page) {
        var e = template
        e.id = UUID()
        let n = Double(page.elements.count % 6)
        e.x = Double(PageMetrics.width) / 2 + n * 18 - 45
        e.y = 430 + n * 22
        if e.kind.isPhysical { e.rotation = [-5, 3, -2, 6, -4, 2][page.elements.count % 6] }
        editor.mode = .stick
        editor.justAdded = e.id
        editor.selectedElement = e.id
        store.addElement(e, to: page.id)
        if e.kind == .note || e.kind == .text { editingText = e }
    }

    private func go(_ i: Int) {
        guard let nb = store.notebook(notebookID), nb.pages.indices.contains(i) else { return }
        Haptics.tap()
        index = i
    }

    private func addPage(after i: Int, paper: PaperStyle?) {
        index = store.addPage(to: notebookID, after: i, paper: paper)
        Haptics.success()
    }

    private func ask(_ kind: AgentPrompt, _ nb: Notebook, _ page: Page, _ i: Int) {
        busy = true
        Task {
            let image = Exporter.image(page)
            let handwriting = await OCR.text(from: Exporter.inkImage(page))
            let text = kind.message(notebook: nb.title, pageNumber: i + 1, typed: page.text, handwriting: handwriting)
            busy = false
            share = ShareItems(items: [image, text])
        }
    }

    private func copyText(_ page: Page) {
        busy = true
        Task {
            let handwriting = await OCR.text(from: Exporter.inkImage(page))
            UIPasteboard.general.string = [page.text, handwriting].filter { !$0.isEmpty }.joined(separator: "\n\n")
            busy = false
            Haptics.success()
        }
    }
}

/// Thumbnail overview of every page: jump, duplicate, delete.
struct PageGrid: View {
    let notebookID: UUID
    @Binding var index: Int
    @Environment(NoteStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110, maximum: 170), spacing: 16)], spacing: 18) {
                    ForEach(Array((store.notebook(notebookID)?.pages ?? []).enumerated()), id: \.element.id) { i, page in
                        Button {
                            index = i
                            dismiss()
                        } label: {
                            VStack(spacing: 6) {
                                PageThumb(page: page)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor, lineWidth: i == index ? 3 : 0))
                                Text(verbatim: "\(i + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button { store.duplicatePage(page.id, in: notebookID) } label: { Label("Duplicate Page", systemImage: "plus.square.on.square") }
                            Button(role: .destructive) {
                                store.deletePage(page.id, in: notebookID)
                                index = min(index, max(0, (store.notebook(notebookID)?.pages.count ?? 1) - 1))
                            } label: { Label("Delete Page", systemImage: "trash") }
                        }
                    }
                }
                .padding(18)
            }
            .background(Desk.color)
            .navigationTitle("Pages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct PageThumb: View {
    let page: Page
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                PaperView(style: page.paper, tone: .light)
            }
        }
        .aspectRatio(210.0 / 297.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        .task(id: page.updatedAt) { image = Exporter.image(page, scale: 0.4) }
    }
}
