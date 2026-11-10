import Foundation
import WatchConnectivity
import WidgetKit

/// Hands the home-screen widget its data.
@MainActor
enum WidgetBridge {
    static func update() {
        let store = NoteStore.shared
        guard let nb = store.mostRecentNotebook else { return }
        WidgetSnapshot(book: nb.title, color: nb.color, pages: nb.pages.count,
                       note: String((store.recentTextPages(limit: 1).first?.page.text ?? "").prefix(300))).save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// Keeps the watch app up to date and receives the notes dictated on the wrist.
final class PhoneSync: NSObject, WCSessionDelegate {
    static let shared = PhoneSync()

    @MainActor
    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    @MainActor
    func push() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        let store = NoteStore.shared
        let notes = store.recentTextPages(limit: 20).map {
            WatchNote(id: $0.page.id.uuidString, book: $0.book.title, text: String($0.page.text.prefix(400)), date: $0.page.updatedAt)
        }
        let books = store.notebooks.prefix(30).map {
            WatchBook(id: $0.id.uuidString, title: $0.title, color: $0.color, pages: $0.pages.count)
        }
        let encoder = JSONEncoder()
        guard let n = try? encoder.encode(notes), let b = try? encoder.encode(Array(books)) else { return }
        try? WCSession.default.updateApplicationContext([SyncKey.notes: n, SyncKey.books: b])
    }

    private func receive(_ payload: [String: Any]) {
        guard let text = payload[SyncKey.quickNote] as? String else { return }
        Task { @MainActor in NoteStore.shared.quickNote(text) }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.push() }
    }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) { receive(userInfo) }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) { receive(message) }
}
