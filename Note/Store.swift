import Foundation
import PencilKit
import SwiftUI
import UIKit

/// The whole library lives on the device: `library.json` plus one PencilKit file per page.
@MainActor
@Observable
final class NoteStore {
    static let shared = NoteStore()

    private(set) var notebooks: [Notebook] = []
    /// Bumped when a page drawing is replaced from outside its canvas (clear, duplicate).
    private(set) var revisions: [UUID: Int] = [:]
    /// The notebook currently open on screen, if any.
    var activeNotebookID: UUID?
    /// The folded-phone cover is covering the app (tool palettes must stay away).
    var coverUp = false

    @ObservationIgnored private var drawings: [UUID: PKDrawing] = [:]
    @ObservationIgnored private var covers = NSCache<NSString, UIImage>()
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private let dir: URL
    @ObservationIgnored var onSave: (() -> Void)?

    private init() {
        dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for sub in ["drawings", "covers"] {
            try? FileManager.default.createDirectory(at: dir.appendingPathComponent(sub), withIntermediateDirectories: true)
        }
        if let data = try? Data(contentsOf: libraryURL),
           let saved = try? JSONDecoder().decode([Notebook].self, from: data) {
            notebooks = saved
        }
        if notebooks.isEmpty {
            notebooks = [Notebook(title: String(localized: "Composition Book"), pages: [Page(paper: .squared)])]
            save()
        }
    }

    private var libraryURL: URL { dir.appendingPathComponent("library.json") }
    private func drawingURL(_ id: UUID) -> URL { dir.appendingPathComponent("drawings/\(id.uuidString).drawing") }
    private func coverURL(_ id: UUID) -> URL { dir.appendingPathComponent("covers/\(id.uuidString).jpg") }

    private func save() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard let self, !Task.isCancelled else { return }
            if let data = try? JSONEncoder().encode(self.notebooks) {
                try? data.write(to: self.libraryURL, options: .atomic)
            }
            self.onSave?()
        }
    }

    // MARK: Lookup

    func notebook(_ id: UUID) -> Notebook? { notebooks.first { $0.id == id } }

    func page(_ notebookID: UUID, _ pageID: UUID) -> Page? {
        notebook(notebookID)?.pages.first { $0.id == pageID }
    }

    private func mutate(_ id: UUID, _ change: (inout Notebook) -> Void) {
        guard let i = notebooks.firstIndex(where: { $0.id == id }) else { return }
        change(&notebooks[i])
        notebooks[i].updatedAt = Date()
        save()
    }

    private func mutatePage(_ pageID: UUID, _ change: (inout Page) -> Void) {
        for i in notebooks.indices {
            if let j = notebooks[i].pages.firstIndex(where: { $0.id == pageID }) {
                change(&notebooks[i].pages[j])
                notebooks[i].pages[j].updatedAt = Date()
                notebooks[i].updatedAt = Date()
                save()
                return
            }
        }
    }

    // MARK: Notebooks

    func upsert(_ notebook: Notebook, photo: UIImage?) {
        var nb = notebook
        if nb.title.trimmingCharacters(in: .whitespaces).isEmpty { nb.title = String(localized: "Composition Book") }
        if nb.pages.isEmpty { nb.pages = [Page(paper: nb.paper)] }
        if let photo, let data = photo.jpegData(compressionQuality: 0.85) {
            try? data.write(to: coverURL(nb.id), options: .atomic)
            covers.setObject(photo, forKey: nb.id.uuidString as NSString)
        }
        if let i = notebooks.firstIndex(where: { $0.id == nb.id }) {
            notebooks[i] = nb
        } else {
            notebooks.insert(nb, at: 0)
        }
        save()
    }

    func delete(_ id: UUID) {
        guard let nb = notebook(id) else { return }
        for page in nb.pages { removeDrawing(page.id) }
        try? FileManager.default.removeItem(at: coverURL(id))
        notebooks.removeAll { $0.id == id }
        save()
    }

    func coverPhoto(_ id: UUID) -> UIImage? {
        if let hit = covers.object(forKey: id.uuidString as NSString) { return hit }
        guard let image = UIImage(contentsOfFile: coverURL(id).path) else { return nil }
        covers.setObject(image, forKey: id.uuidString as NSString)
        return image
    }

    func setLastIndex(_ index: Int, in id: UUID) {
        guard let i = notebooks.firstIndex(where: { $0.id == id }), notebooks[i].lastIndex != index else { return }
        notebooks[i].lastIndex = index
        save()
    }

    // MARK: Pages

    /// Adds a page after `index` and returns the new page's index.
    @discardableResult
    func addPage(to id: UUID, after index: Int, paper: PaperStyle? = nil, text: String = "") -> Int {
        var newIndex = 0
        mutate(id) { nb in
            newIndex = min(index + 1, nb.pages.count)
            nb.pages.insert(Page(paper: paper ?? nb.paper, text: text), at: newIndex)
        }
        return newIndex
    }

    func deletePage(_ pageID: UUID, in id: UUID) {
        mutate(id) { nb in
            nb.pages.removeAll { $0.id == pageID }
            if nb.pages.isEmpty { nb.pages = [Page(paper: nb.paper)] }
        }
        removeDrawing(pageID)
    }

    func duplicatePage(_ pageID: UUID, in id: UUID) {
        guard let nb = notebook(id), let i = nb.pages.firstIndex(where: { $0.id == pageID }) else { return }
        let source = nb.pages[i]
        var copy = Page(paper: source.paper, text: source.text)
        copy.elements = source.elements.map { var e = $0; e.id = UUID(); return e }
        saveDrawing(drawing(for: pageID), for: copy.id, touch: false)
        mutate(id) { $0.pages.insert(copy, at: i + 1) }
    }

    func setPaper(_ paper: PaperStyle, page pageID: UUID) { mutatePage(pageID) { $0.paper = paper } }
    func setText(_ text: String, page pageID: UUID) { mutatePage(pageID) { $0.text = text } }

    // MARK: Elements (stickers, notes, text boxes, shapes)

    func addElement(_ element: PageElement, to pageID: UUID) {
        mutatePage(pageID) { $0.elements.append(element) }
    }

    func updateElement(_ element: PageElement, on pageID: UUID) {
        mutatePage(pageID) { page in
            if let i = page.elements.firstIndex(where: { $0.id == element.id }) { page.elements[i] = element }
        }
    }

    func removeElement(_ id: UUID, from pageID: UUID) {
        mutatePage(pageID) { $0.elements.removeAll { $0.id == id } }
    }

    func bringElementToFront(_ id: UUID, on pageID: UUID) {
        mutatePage(pageID) { page in
            if let i = page.elements.firstIndex(where: { $0.id == id }) { page.elements.append(page.elements.remove(at: i)) }
        }
    }

    // MARK: Drawings

    func drawing(for pageID: UUID) -> PKDrawing {
        if let hit = drawings[pageID] { return hit }
        let loaded = (try? Data(contentsOf: drawingURL(pageID))).flatMap { try? PKDrawing(data: $0) } ?? PKDrawing()
        drawings[pageID] = loaded
        return loaded
    }

    func saveDrawing(_ drawing: PKDrawing, for pageID: UUID, touch: Bool = true) {
        drawings[pageID] = drawing
        let url = drawingURL(pageID)
        let data = drawing.dataRepresentation()
        DispatchQueue.global(qos: .utility).async { try? data.write(to: url, options: .atomic) }
        if touch { mutatePage(pageID) { _ in } }
    }

    func clearDrawing(_ pageID: UUID) {
        saveDrawing(PKDrawing(), for: pageID)
        revisions[pageID, default: 0] += 1
    }

    private func removeDrawing(_ pageID: UUID) {
        drawings[pageID] = nil
        try? FileManager.default.removeItem(at: drawingURL(pageID))
    }

    // MARK: Quick notes (widget-free capture used by the watch, Siri and quick actions)

    func quickNote(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let nb = notebooks.first(where: { $0.isQuick }) {
            if nb.pages.count == 1, nb.pages[0].text.isEmpty, drawing(for: nb.pages[0].id).strokes.isEmpty {
                setText(trimmed, page: nb.pages[0].id)
            } else {
                addPage(to: nb.id, after: nb.pages.count - 1, paper: .lined, text: trimmed)
            }
        } else {
            let nb = Notebook(title: String(localized: "Quick Notes"), color: .teal, art: .waves, paper: .lined,
                              pages: [Page(paper: .lined, text: trimmed)], isQuick: true)
            notebooks.insert(nb, at: 0)
            save()
        }
    }

    /// Pages that carry typed text, newest first.
    func recentTextPages(limit: Int = 25) -> [(book: Notebook, page: Page)] {
        notebooks
            .flatMap { nb in nb.pages.filter { !$0.text.isEmpty }.map { (book: nb, page: $0) } }
            .sorted { $0.page.updatedAt > $1.page.updatedAt }
            .prefix(limit)
            .map { $0 }
    }

    var mostRecentNotebook: Notebook? { notebooks.max { $0.updatedAt < $1.updatedAt } }
}
