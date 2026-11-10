import AppIntents

/// App Intents make the notebook reachable from Siri, Shortcuts, Spotlight and
/// any assistant that can run shortcuts.
struct QuickNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Quick Note"
    static let description = IntentDescription("Adds a text note to the Quick Notes notebook.")

    @Parameter(title: "Text")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        NoteStore.shared.quickNote(text)
        return .result(dialog: "Saved to Quick Notes.")
    }
}

struct LatestNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Latest Note"
    static let description = IntentDescription("Returns the text of the most recently edited page.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: NoteStore.shared.recentTextPages(limit: 1).first?.page.text ?? "")
    }
}

struct ContinueWritingIntent: AppIntent {
    static let title: LocalizedStringResource = "Continue Writing"
    static let description = IntentDescription("Opens the notebook you used last.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        Router.shared.pending = .continueLast
        return .result()
    }
}

struct NoteShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: QuickNoteIntent(),
                    phrases: ["Add a quick note in \(.applicationName)", "New \(.applicationName) quick note"],
                    shortTitle: "Quick Note", systemImageName: "bolt.fill")
        AppShortcut(intent: ContinueWritingIntent(),
                    phrases: ["Continue writing in \(.applicationName)"],
                    shortTitle: "Continue Writing", systemImageName: "pencil.tip")
        AppShortcut(intent: LatestNoteIntent(),
                    phrases: ["Get my latest \(.applicationName) note"],
                    shortTitle: "Latest Note", systemImageName: "doc.text")
    }
}
