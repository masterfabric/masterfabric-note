import SwiftUI

struct LibraryView: View {
    @Environment(NoteStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @State private var router = Router.shared
    @State private var path: [UUID] = []
    @State private var draft: Notebook?
    @State private var showQuick = false
    @State private var showSettings = false
    @State private var deleting: Notebook?
    @State private var share: ShareItems?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 230), spacing: 22)], spacing: 28) {
                    ForEach(store.notebooks) { nb in
                        Button {
                            Haptics.tap()
                            path = [nb.id]
                        } label: {
                            VStack(spacing: 8) {
                                CoverView(nb)
                                    .shadow(color: .black.opacity(0.28), radius: 7, x: 3, y: 5)
                                Text(nb.title).font(.footnote.weight(.semibold)).lineLimit(1)
                                Text("\(nb.pages.count) pages")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button { draft = nb } label: { Label("Edit Cover", systemImage: "paintpalette") }
                            Button { share = ShareItems(items: [Exporter.pdf(nb)]) } label: { Label("Share as PDF", systemImage: "square.and.arrow.up") }
                            Button(role: .destructive) { deleting = nb } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                }
                .padding(20)
            }
            .background(Desk.color)
            .navigationTitle("Notebooks")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showQuick = true } label: { Label("Quick Note", systemImage: "bolt.fill") }
                    Button { newNotebook() } label: { Label("New Notebook", systemImage: "plus") }
                        .keyboardShortcut("n", modifiers: [.command, .shift])
                }
            }
            .navigationDestination(for: UUID.self) { id in
                NotebookView(notebookID: id)
            }
        }
        .sheet(item: $draft) { nb in NotebookEditor(notebook: nb) }
        .sheet(isPresented: $showQuick) { QuickNoteSheet() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(item: $share) { ActivityView(items: $0.items) }
        .confirmationDialog("Delete this notebook and all of its pages?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let deleting { store.delete(deleting.id) }
                deleting = nil
            }
        }
        .onChange(of: router.pending, initial: true) { _, action in
            guard let action else { return }
            router.pending = nil
            switch action {
            case .quickNote: showQuick = true
            case .newNotebook: newNotebook()
            case .continueLast: if let nb = store.mostRecentNotebook { path = [nb.id] }
            case .editCover(let id): draft = store.notebook(id)
            }
        }
    }

    private func newNotebook() {
        draft = Notebook(title: "", color: settings.defaultColor, paper: settings.defaultPaper)
    }
}

struct QuickNoteSheet: View {
    @Environment(NoteStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .focused($focused)
                .font(.title3)
                .padding()
                .navigationTitle("Quick Note")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            store.quickNote(text)
                            Haptics.success()
                            dismiss()
                        }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
    }
}
