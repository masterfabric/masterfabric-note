import Foundation
import SwiftUI

/// Canonical page geometry: an A4 sheet at 4 pt per millimetre.
enum PageMetrics {
    static let width: CGFloat = 840
    static let height: CGFloat = 1188
    static var size: CGSize { CGSize(width: width, height: height) }
}

enum PaperStyle: String, Codable, CaseIterable, Identifiable {
    case squared, lined, guide, dotted, isometric, blank
    var id: String { rawValue }

    var title: String {
        switch self {
        case .squared: String(localized: "Squared")
        case .lined: String(localized: "Lined")
        case .guide: String(localized: "Guide lines")
        case .dotted: String(localized: "Dotted")
        case .isometric: String(localized: "Geometric")
        case .blank: String(localized: "Blank")
        }
    }

    var symbol: String {
        switch self {
        case .squared: "grid"
        case .lined: "line.3.horizontal"
        case .guide: "textformat.abc"
        case .dotted: "circle.grid.3x3"
        case .isometric: "triangle"
        case .blank: "rectangle.portrait"
        }
    }
}

enum CoverColor: String, Codable, CaseIterable, Identifiable {
    case black, red, green, blue, purple, teal, coral
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .black: Color(red: 0.05, green: 0.05, blue: 0.06)
        case .red: Color(red: 0.82, green: 0.15, blue: 0.15)
        case .green: Color(red: 0.08, green: 0.56, blue: 0.27)
        case .blue: Color(red: 0.12, green: 0.26, blue: 0.72)
        case .purple: Color(red: 0.62, green: 0.12, blue: 0.62)
        case .teal: Color(red: 0.13, green: 0.72, blue: 0.62)
        case .coral: Color(red: 0.94, green: 0.33, blue: 0.36)
        }
    }

    var title: String {
        switch self {
        case .black: String(localized: "Black")
        case .red: String(localized: "Red")
        case .green: String(localized: "Green")
        case .blue: String(localized: "Blue")
        case .purple: String(localized: "Purple")
        case .teal: String(localized: "Teal")
        case .coral: String(localized: "Coral")
        }
    }
}

enum CoverArt: String, Codable, CaseIterable, Identifiable {
    case marble, waves, rings, mosaic, photo
    var id: String { rawValue }

    var title: String {
        switch self {
        case .marble: String(localized: "Marble")
        case .waves: String(localized: "Waves")
        case .rings: String(localized: "Rings")
        case .mosaic: String(localized: "Mosaic")
        case .photo: String(localized: "Photo")
        }
    }
}

enum ElementKind: String, Codable {
    case sticker, label, note, tape, text, shape
    /// Paper things that sit on the page and cast a shadow; text and shapes are flat.
    var isPhysical: Bool { self == .sticker || self == .label || self == .note || self == .tape }
    var hasText: Bool { self == .label || self == .note || self == .text }
}

enum ElementColor: String, Codable, CaseIterable {
    case yellow, pink, blue, green, orange, purple, red, black
}

enum ElementTextStyle: String, Codable, CaseIterable {
    case title, marker, typewriter, script, bubble
    var title: String {
        switch self {
        case .title: String(localized: "Title")
        case .marker: String(localized: "Highlight")
        case .typewriter: String(localized: "Typewriter")
        case .script: String(localized: "Script")
        case .bubble: String(localized: "Bubble")
        }
    }
}

/// Something stuck onto a page: a sticker, label, sticky note, tape, text box or shape.
/// Position and width are in canonical page points.
struct PageElement: Codable, Identifiable, Hashable {
    var id = UUID()
    var kind: ElementKind
    var x: Double = 420
    var y: Double = 420
    var width: Double = 200
    var rotation: Double = 0
    var symbol = ""
    var text = ""
    var style = ElementTextStyle.title
    var color = ElementColor.black
}

struct Page: Codable, Identifiable, Hashable {
    var id = UUID()
    var paper: PaperStyle
    var text = ""
    var createdAt = Date()
    var updatedAt = Date()
    var elements: [PageElement] = []
}

extension Page {
    // Libraries saved before elements existed have no `elements` key.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        paper = try c.decode(PaperStyle.self, forKey: .paper)
        text = try c.decode(String.self, forKey: .text)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        elements = try c.decodeIfPresent([PageElement].self, forKey: .elements) ?? []
    }
}

struct Notebook: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var color: CoverColor = .black
    var art: CoverArt = .marble
    var paper: PaperStyle = .squared
    var pages: [Page] = []
    var createdAt = Date()
    var updatedAt = Date()
    var lastIndex = 0
    var isQuick = false

    var seed: UInt64 { withUnsafeBytes(of: id.uuid) { $0.load(as: UInt64.self) } }
}

/// Small deterministic generator so every cover keeps its own pattern.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// Payload keys shared by the phone and the watch.
enum SyncKey {
    static let notes = "notes"
    static let books = "books"
    static let quickNote = "quickNote"
}

struct WatchNote: Codable, Identifiable, Hashable {
    var id: String
    var book: String
    var text: String
    var date: Date
}

struct WatchBook: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var color: CoverColor
    var pages: Int
}

/// What the home-screen widget shows; written by the app into the shared app group.
struct WidgetSnapshot: Codable {
    var book = ""
    var color = CoverColor.black
    var pages = 0
    var note = ""

    static let suite = "group.com.masterfabric.note"
    static let key = "widget.snapshot"

    static func load() -> WidgetSnapshot {
        guard let data = UserDefaults(suiteName: suite)?.data(forKey: key),
              let snap = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else { return WidgetSnapshot() }
        return snap
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Self.suite)?.set(data, forKey: Self.key)
    }
}
