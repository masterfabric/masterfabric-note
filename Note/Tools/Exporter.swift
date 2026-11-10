import PencilKit
import SwiftUI
import UIKit
import Vision

struct ShareItems: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

@MainActor
enum Exporter {
    /// A4, grown to include any ink drawn on the extra paper a tall or wide screen shows.
    private static func bounds(_ page: Page) -> CGRect {
        let ink = NoteStore.shared.drawing(for: page.id).bounds
        var maxX = PageMetrics.width, maxY = PageMetrics.height
        if !ink.isNull, !ink.isEmpty {
            maxX = max(maxX, ink.maxX + 40)
            maxY = max(maxY, ink.maxY + 40)
        }
        for e in page.elements {
            maxX = max(maxX, e.x + e.width / 2 + 20)
            maxY = max(maxY, e.y + e.width / 2 + 20)
        }
        return CGRect(x: 0, y: 0, width: min(maxX, PageMetrics.width * 3), height: min(maxY, PageMetrics.height * 3))
    }

    private static func ink(_ page: Page, scale: CGFloat) -> UIImage {
        let drawing = NoteStore.shared.drawing(for: page.id)
        let rect = bounds(page)
        var image = UIImage()
        // Always export on light paper, whatever the app is showing.
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            image = drawing.image(from: rect, scale: scale)
        }
        return image
    }

    /// The page as it looks on light paper: ruling, typed text and ink.
    static func image(_ page: Page, scale: CGFloat = 2) -> UIImage {
        let rect = bounds(page)
        let base = ImageRenderer(content: ZStack {
            PaperView(style: page.paper, tone: .light, mm: PageMetrics.width / 210)
            PageTextLayer(page: page, tone: .light)
            StaticElements(elements: page.elements, tone: .light)
        }
        .frame(width: rect.width, height: rect.height)
        .environment(\.colorScheme, .light))
        base.scale = scale
        let paper = base.uiImage
        let strokes = ink(page, scale: scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: rect.size, format: format).image { _ in
            UIColor.white.setFill()
            UIRectFill(rect)
            paper?.draw(in: rect)
            strokes.draw(in: rect)
        }
    }

    /// Ink on plain white, which is what text recognition reads best.
    static func inkImage(_ page: Page) -> UIImage {
        let rect = bounds(page)
        let strokes = ink(page, scale: 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        return UIGraphicsImageRenderer(size: rect.size, format: format).image { _ in
            UIColor.white.setFill()
            UIRectFill(rect)
            strokes.draw(in: rect)
        }
    }

    /// Writes the notebook to a temporary A4 PDF and returns its URL.
    static func pdf(_ notebook: Notebook) -> URL {
        let a4 = CGRect(x: 0, y: 0, width: 595, height: 842)
        let name = notebook.title.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: a4)
        try? renderer.writePDF(to: url) { ctx in
            for page in notebook.pages {
                ctx.beginPage()
                let img = image(page, scale: 2)
                let k = min(a4.width / img.size.width, a4.height / img.size.height)
                img.draw(in: CGRect(x: 0, y: 0, width: img.size.width * k, height: img.size.height * k))
            }
        }
        return url
    }
}

enum OCR {
    /// Recognises handwriting on the device; nothing leaves the phone.
    static func text(from image: UIImage) async -> String {
        guard let cg = image.cgImage else { return "" }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.automaticallyDetectsLanguage = true
                try? VNImageRequestHandler(cgImage: cg).perform([request])
                let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
        }
    }
}

/// Ready-made requests that travel with the page when it is handed to an AI agent
/// (Claude, ChatGPT, Gemini, … whatever is installed) through the share sheet.
enum AgentPrompt {
    case summarize, todo, clean

    var instruction: String {
        switch self {
        case .summarize: String(localized: "Summarize this notebook page in a few bullet points.")
        case .todo: String(localized: "Turn this notebook page into a clear to-do list.")
        case .clean: String(localized: "Rewrite this notebook page as clean, well-organized notes. Keep every fact.")
        }
    }

    func message(notebook: String, pageNumber: Int, typed: String, handwriting: String) -> String {
        var parts = [instruction, String(localized: "Notebook: \(notebook) · page \(pageNumber). The page image is attached.")]
        if !typed.isEmpty { parts.append(String(localized: "Typed text:") + "\n" + typed) }
        if !handwriting.isEmpty { parts.append(String(localized: "Handwriting (recognized on device):") + "\n" + handwriting) }
        return parts.joined(separator: "\n\n")
    }
}
