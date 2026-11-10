import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $settings.appearance) {
                        ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Warm reading paper", isOn: $settings.sepiaPaper)
                    Toggle("Open notebooks in reading mode", isOn: $settings.openInReading)
                    Toggle("Show cover when folded", isOn: $settings.foldCover)
                }
                Section {
                    Picker("Page turn", selection: $settings.turnStyle) {
                        ForEach(TurnStyle.allCases) { Text($0.title).tag($0) }
                    }
                } header: { Text("Pages") } footer: {
                    Text("In reading mode, swipe to turn pages. While drawing with a finger, use the arrows at the top.")
                }
                Section {
                    Toggle("Draw only with Apple Pencil", isOn: $settings.pencilOnly)
                    Toggle("Haptic feedback", isOn: $settings.haptics)
                } header: { Text("Writing") } footer: {
                    Text("With Apple Pencil only, your finger turns pages and the Pencil writes.")
                }
                Section("New notebooks") {
                    Picker("Paper", selection: $settings.defaultPaper) {
                        ForEach(PaperStyle.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                    }
                    Picker("Cover color", selection: $settings.defaultColor) {
                        ForEach(CoverColor.allCases) { Text($0.title).tag($0) }
                    }
                }
                Section {
                    HStack(spacing: 14) {
                        CoverView(title: "Note", color: .black, art: .marble, seed: 7)
                            .frame(height: 64)
                            .shadow(color: .black.opacity(0.25), radius: 3, x: 1, y: 2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: "Note").font(.headline)
                            Text(verbatim: "MasterFabric").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    LabeledContent("Author") { Text(verbatim: "Gürkan Fikret Günak") }
                    Link(destination: URL(string: "https://masterfabric.co")!) {
                        LabeledContent("Website") { Text(verbatim: "masterfabric.co") }
                    }
                    Link(destination: URL(string: "https://github.com/gurkanfikretgunak")!) {
                        LabeledContent("GitHub") { Text(verbatim: "@gurkanfikretgunak") }
                    }
                } header: { Text("About") } footer: {
                    Text("Your notebooks stay on this device.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
