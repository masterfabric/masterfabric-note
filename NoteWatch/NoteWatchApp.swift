import SwiftUI
import WatchConnectivity

@main
struct NoteWatchApp: App {
    @State private var store = WatchStore()

    var body: some Scene {
        WindowGroup {
            WatchHome().environment(store)
        }
    }
}

@Observable
final class WatchStore: NSObject, WCSessionDelegate {
    var notes: [WatchNote] = []
    var books: [WatchBook] = []
    /// Notes written on the watch that are on their way to the phone.
    var sent: [WatchNote] = []

    override init() {
        super.init()
        let d = UserDefaults.standard
        let decoder = JSONDecoder()
        if let data = d.data(forKey: SyncKey.notes) { notes = (try? decoder.decode([WatchNote].self, from: data)) ?? [] }
        if let data = d.data(forKey: SyncKey.books) { books = (try? decoder.decode([WatchBook].self, from: data)) ?? [] }
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func add(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        sent.insert(WatchNote(id: UUID().uuidString, book: String(localized: "Quick Notes"), text: trimmed, date: Date()), at: 0)
        WCSession.default.transferUserInfo([SyncKey.quickNote: trimmed])
    }

    private func apply(_ context: [String: Any]) {
        let decoder = JSONDecoder()
        let n = (context[SyncKey.notes] as? Data).flatMap { try? decoder.decode([WatchNote].self, from: $0) }
        let b = (context[SyncKey.books] as? Data).flatMap { try? decoder.decode([WatchBook].self, from: $0) }
        DispatchQueue.main.async {
            if let n {
                self.notes = n
                self.sent.removeAll { pending in n.contains { $0.text == pending.text } }
                UserDefaults.standard.set(context[SyncKey.notes], forKey: SyncKey.notes)
            }
            if let b {
                self.books = b
                UserDefaults.standard.set(context[SyncKey.books], forKey: SyncKey.books)
            }
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        apply(session.receivedApplicationContext)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(applicationContext)
    }
}

struct WatchHome: View {
    @Environment(WatchStore.self) private var store
    @State private var composing = false

    var body: some View {
        NavigationStack {
            List {
                Button { composing = true } label: {
                    Label("Quick Note", systemImage: "bolt.fill").font(.headline)
                }
                .listRowBackground(RoundedRectangle(cornerRadius: 14).fill(CoverColor.blue.color))

                if !store.books.isEmpty {
                    Section("Notebooks") {
                        ForEach(store.books) { book in
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 3).fill(book.color.color)
                                    .frame(width: 16, height: 22)
                                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(.white.opacity(0.5), lineWidth: 0.5))
                                VStack(alignment: .leading) {
                                    Text(book.title).lineLimit(1)
                                    Text("\(book.pages) pages").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Recent notes") {
                    if store.sent.isEmpty && store.notes.isEmpty {
                        Text("Notes you type on iPhone show up here.").font(.footnote).foregroundStyle(.secondary)
                    }
                    ForEach(store.sent + store.notes) { note in
                        NavigationLink {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(note.book).font(.caption2).foregroundStyle(.secondary)
                                    Text(note.text)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .navigationTitle(Text(note.date, style: .date))
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(note.text).lineLimit(2)
                                Text(note.date, style: .relative).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Note")
            .sheet(isPresented: $composing) { WatchCompose() }
        }
    }
}

struct WatchCompose: View {
    @Environment(WatchStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        VStack(spacing: 10) {
            TextField("Write or dictate", text: $text, axis: .vertical)
                .lineLimit(1...4)
            Button("Save") {
                store.add(text)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 4)
    }
}
