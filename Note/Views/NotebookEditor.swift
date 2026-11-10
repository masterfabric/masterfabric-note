import PhotosUI
import SwiftUI

/// Create a notebook or restyle an existing one, with a live cover you can tilt.
struct NotebookEditor: View {
    @Environment(NoteStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var notebook: Notebook
    @State private var photo: UIImage?
    @State private var picked: PhotosPickerItem?
    @State private var tilt: CGSize = .zero

    private var isNew: Bool { store.notebook(notebook.id) == nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    CoverView(title: notebook.title.isEmpty ? String(localized: "Composition Book") : notebook.title,
                              color: notebook.color, art: notebook.art, seed: notebook.seed,
                              photo: photo ?? store.coverPhoto(notebook.id),
                              footer: CoverView.footer(for: notebook))
                        .frame(height: 280)
                        .frame(maxWidth: .infinity)
                        .shadow(color: .black.opacity(0.35), radius: 14, x: 6 - tilt.width / 6, y: 10)
                        .rotation3DEffect(.degrees(Double(tilt.width) / 4), axis: (0, 1, 0), perspective: 0.6)
                        .rotation3DEffect(.degrees(Double(-tilt.height) / 6), axis: (1, 0, 0), perspective: 0.6)
                        .gesture(DragGesture()
                            .onChanged { tilt = CGSize(width: max(-140, min(140, $0.translation.width)), height: max(-90, min(90, $0.translation.height))) }
                            .onEnded { _ in withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { tilt = .zero } })
                        .padding(.vertical, 8)

                    TextField("Notebook name", text: $notebook.title)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)

                    section("Cover color") {
                        HStack(spacing: 12) {
                            ForEach(CoverColor.allCases) { c in
                                Button { notebook.color = c; Haptics.tap() } label: {
                                    Circle().fill(c.color).frame(width: 34, height: 34)
                                        .overlay(Circle().stroke(Color.primary.opacity(0.25), lineWidth: 1))
                                        .overlay(Circle().stroke(Color.accentColor, lineWidth: notebook.color == c ? 3 : 0).padding(-4))
                                }
                                .accessibilityLabel(c.title)
                            }
                        }
                    }

                    section("Cover pattern") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(CoverArt.allCases.filter { $0 != .photo }) { art in
                                    Button { notebook.art = art; Haptics.tap() } label: {
                                        VStack(spacing: 6) {
                                            CoverView(title: "", color: notebook.color, art: art, seed: notebook.seed)
                                                .frame(height: 96)
                                                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.accentColor, lineWidth: notebook.art == art ? 3 : 0).padding(-4))
                                            Text(art.title).font(.caption)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                                PhotosPicker(selection: $picked, matching: .images) {
                                    VStack(spacing: 6) {
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                                            .frame(width: 68, height: 96)
                                            .overlay(Image(systemName: "photo.badge.plus").font(.title2))
                                        Text("Photo").font(.caption)
                                    }
                                }
                            }
                            .padding(6)
                        }
                    }

                    section("Paper") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(PaperStyle.allCases) { style in
                                    Button { notebook.paper = style; Haptics.tap() } label: {
                                        VStack(spacing: 6) {
                                            PaperThumb(style: style, selected: notebook.paper == style)
                                            Text(style.title).font(.caption)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(4)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle(isNew ? "New Notebook" : "Edit Cover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Create" : "Save") {
                        store.upsert(notebook, photo: photo)
                        Haptics.success()
                        dismiss()
                    }
                }
            }
            .onChange(of: picked) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        photo = image
                        notebook.art = .photo
                    }
                }
            }
        }
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
    }
}
