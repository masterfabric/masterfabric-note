import SwiftUI
import UIKit

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var scheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
    var title: String {
        switch self {
        case .system: String(localized: "System")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }
}

enum TurnStyle: String, CaseIterable, Identifiable {
    case curl, slide
    var id: String { rawValue }
    var title: String {
        switch self {
        case .curl: String(localized: "3D page curl")
        case .slide: String(localized: "2D slide")
        }
    }
}

@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()
    @ObservationIgnored private let d = UserDefaults.standard

    var appearance: Appearance { didSet { d.set(appearance.rawValue, forKey: "appearance") } }
    var turnStyle: TurnStyle { didSet { d.set(turnStyle.rawValue, forKey: "turnStyle") } }
    var defaultPaper: PaperStyle { didSet { d.set(defaultPaper.rawValue, forKey: "defaultPaper") } }
    var defaultColor: CoverColor { didSet { d.set(defaultColor.rawValue, forKey: "defaultColor") } }
    /// Warm, low-glare paper for reading.
    var sepiaPaper: Bool { didSet { d.set(sepiaPaper, forKey: "sepiaPaper") } }
    var openInReading: Bool { didSet { d.set(openInReading, forKey: "openInReading") } }
    var pencilOnly: Bool { didSet { d.set(pencilOnly, forKey: "pencilOnly") } }
    var haptics: Bool { didSet { d.set(haptics, forKey: "haptics") } }
    /// Foldables: show the notebook cover while the device is folded shut.
    var foldCover: Bool { didSet { d.set(foldCover, forKey: "foldCover") } }

    private init() {
        appearance = Appearance(rawValue: d.string(forKey: "appearance") ?? "") ?? .system
        turnStyle = TurnStyle(rawValue: d.string(forKey: "turnStyle") ?? "") ?? .curl
        defaultPaper = PaperStyle(rawValue: d.string(forKey: "defaultPaper") ?? "") ?? .squared
        defaultColor = CoverColor(rawValue: d.string(forKey: "defaultColor") ?? "") ?? .black
        sepiaPaper = d.bool(forKey: "sepiaPaper")
        openInReading = d.bool(forKey: "openInReading")
        pencilOnly = d.bool(forKey: "pencilOnly")
        haptics = d.object(forKey: "haptics") as? Bool ?? true
        foldCover = d.object(forKey: "foldCover") as? Bool ?? true
    }

    func tone(for scheme: ColorScheme) -> PaperTone {
        scheme == .dark ? .dark : (sepiaPaper ? .sepia : .light)
    }
}

@MainActor
enum Haptics {
    static func tap() {
        guard AppSettings.shared.haptics else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    /// Peeling something off the page.
    static func lift() {
        guard AppSettings.shared.haptics else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
    }
    /// Pressing it back on.
    static func stick() {
        guard AppSettings.shared.haptics else { return }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1)
    }
    static func success() {
        guard AppSettings.shared.haptics else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

/// Entry points that come from outside the UI: home-screen quick actions, URLs, App Intents.
@MainActor
@Observable
final class Router {
    static let shared = Router()
    enum Action: Equatable { case quickNote, newNotebook, continueLast, editCover(UUID) }
    var pending: Action?

    func handle(shortcut type: String) {
        switch type {
        case "quick-note": pending = .quickNote
        case "new-notebook": pending = .newNotebook
        case "continue": pending = .continueLast
        default: break
        }
    }

    func handle(url: URL) {
        guard url.scheme == "mfnote" else { return }
        switch url.host {
        case "quick": pending = .quickNote
        case "new": pending = .newNotebook
        case "continue": pending = .continueLast
        default: break
        }
    }
}

enum Desk {
    static let uiColor = UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(white: 0.05, alpha: 1)
        : UIColor(red: 0.90, green: 0.89, blue: 0.86, alpha: 1) }
    static var color: Color { Color(uiColor: uiColor) }
}
