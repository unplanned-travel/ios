import SwiftUI
import UIKit

/// Thin wrapper around UIActivityViewController so we can use it from SwiftUI sheets.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - PDF generation

extension Plan {
    /// Renders this plan to a PDF file in the temp directory and returns its URL.
    @MainActor
    func generarPDF(etapas: [Etapa]) -> URL {
        let vista = PDFPlanView(plan: self, etapas: etapas)
        let renderer = ImageRenderer(content: vista)
        renderer.scale = 2.0  // Retina quality

        let nombre = titulo.isEmpty ? "viaje" : titulo
        let nombreSeguro = nombre
            .components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespaces)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(nombreSeguro)
            .appendingPathExtension("pdf")

        renderer.render { size, context in
            var box = CGRect(origin: .zero, size: size)
            guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            pdf.beginPDFPage(nil)
            context(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
        }

        return url
    }
}
