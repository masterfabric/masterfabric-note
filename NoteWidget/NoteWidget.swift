import SwiftUI
import WidgetKit

struct NoteEntry: TimelineEntry {
    let date: Date
    let snap: WidgetSnapshot
}

struct NoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> NoteEntry { NoteEntry(date: .now, snap: WidgetSnapshot()) }
    func getSnapshot(in context: Context, completion: @escaping (NoteEntry) -> Void) {
        completion(NoteEntry(date: .now, snap: .load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<NoteEntry>) -> Void) {
        // The app reloads the timeline whenever a notebook changes.
        completion(Timeline(entries: [NoteEntry(date: .now, snap: .load())], policy: .never))
    }
}

/// A tiny composition-book cover.
struct MiniCover: View {
    var title: String
    var color: CoverColor

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .leading) {
                Canvas { ctx, size in
                    ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(color.color))
                    var rng = SeededRandom(seed: 7)
                    var path = Path()
                    for _ in 0..<170 {
                        let r = size.width * CGFloat.random(in: 0.012...0.034, using: &rng)
                        let x = CGFloat.random(in: 0...size.width, using: &rng)
                        let y = CGFloat.random(in: 0...size.height, using: &rng)
                        path.addEllipse(in: CGRect(x: x, y: y, width: r * CGFloat.random(in: 1...2.4, using: &rng),
                                                   height: r * CGFloat.random(in: 0.8...1.8, using: &rng)))
                    }
                    ctx.fill(path, with: .color(.white))
                }
                Rectangle().fill(Color(white: 0.06)).frame(width: w * 0.1)
                ZStack {
                    RoundedRectangle(cornerRadius: w * 0.06).fill(.white)
                    RoundedRectangle(cornerRadius: w * 0.045).inset(by: w * 0.018).stroke(.black, lineWidth: max(1, w * 0.012))
                    Text(title.uppercased())
                        .font(.system(size: w * 0.085, weight: .heavy))
                        .foregroundStyle(.black)
                        .lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.5)
                        .padding(w * 0.05)
                }
                .frame(width: w * 0.66, height: h * 0.24)
                .position(x: w * 0.55, y: h * 0.3)
            }
            .clipShape(RoundedRectangle(cornerRadius: w * 0.05))
        }
        .aspectRatio(210.0 / 297.0, contentMode: .fit)
    }
}

struct NoteWidgetView: View {
    let entry: NoteEntry
    @Environment(\.widgetFamily) private var family

    private var title: String { entry.snap.book.isEmpty ? "Note" : entry.snap.book }

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "bolt.fill").font(.title2)
            }
            .widgetURL(URL(string: "mfnote://quick"))
            .containerBackground(.clear, for: .widget)

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Label(title, systemImage: "book.closed.fill").font(.headline).lineLimit(1)
                Text(entry.snap.note.isEmpty ? String(localized: "No notes yet") : entry.snap.note)
                    .font(.caption).lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(URL(string: "mfnote://continue"))
            .containerBackground(.clear, for: .widget)

        case .systemMedium:
            HStack(spacing: 14) {
                Link(destination: URL(string: "mfnote://continue")!) {
                    MiniCover(title: title, color: entry.snap.color)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 2, y: 3)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.headline).lineLimit(1)
                    Text(entry.snap.note.isEmpty ? String(localized: "No notes yet") : entry.snap.note)
                        .font(.footnote).foregroundStyle(.secondary).lineLimit(3)
                    Spacer(minLength: 0)
                    HStack(spacing: 8) {
                        action("Quick Note", "bolt.fill", "mfnote://quick")
                        action("New Notebook", "plus", "mfnote://new")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .containerBackground(Color(red: 0.93, green: 0.92, blue: 0.89), for: .widget)

        default:
            VStack(spacing: 6) {
                MiniCover(title: title, color: entry.snap.color)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 2, y: 3)
                Text("\(entry.snap.pages) pages").font(.caption2).foregroundStyle(.secondary)
            }
            .widgetURL(URL(string: "mfnote://continue"))
            .containerBackground(Color(red: 0.93, green: 0.92, blue: 0.89), for: .widget)
        }
    }

    private func action(_ title: LocalizedStringKey, _ symbol: String, _ url: String) -> some View {
        Link(destination: URL(string: url)!) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .lineLimit(1).minimumScaleFactor(0.7)
                .padding(.horizontal, 9).padding(.vertical, 7)
                .foregroundStyle(.white)
                .background(Color(red: 0.12, green: 0.26, blue: 0.72), in: Capsule())
        }
    }
}

struct NoteWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NoteWidget", provider: NoteProvider()) { entry in
            NoteWidgetView(entry: entry)
        }
        .configurationDisplayName("Note")
        .description("Continue where you left off, or jot a quick note.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct NoteWidgets: WidgetBundle {
    var body: some Widget { NoteWidget() }
}
