import SwiftUI
import PDFKit
import PencilKit

/// Visor de plano PDF con anotaciones PencilKit.
struct PlanoViewerView: View {
    let plano: Plano

    @State private var pdfData: Data?
    @State private var canvasView = PKCanvasView()
    @State private var isToolPickerVisible = false
    @State private var isSaving = false
    @State private var saveError: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                if let data = pdfData {
                    PDFAnnotationView(
                        pdfData: data,
                        canvasView: $canvasView,
                        isToolPickerVisible: $isToolPickerVisible
                    )
                } else {
                    ProgressView("Cargando plano...")
                }
            }
            .navigationTitle(plano.nombre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Button {
                            isToolPickerVisible.toggle()
                        } label: {
                            Image(systemName: isToolPickerVisible ? "pencil.circle.fill" : "pencil.circle")
                        }

                        Button {
                            Task { await saveAnnotation() }
                        } label: {
                            if isSaving {
                                ProgressView()
                            } else {
                                Label("Guardar copia anotada", systemImage: "square.and.arrow.down")
                            }
                        }
                        .disabled(isSaving)
                    }
                }
            }
            .alert("Error al guardar", isPresented: .constant(saveError != nil)) {
                Button("OK") { saveError = nil }
            } message: {
                Text(saveError ?? "")
            }
            .task { await loadPDF() }
        }
    }

    private func loadPDF() async {
        // Descargar el PDF del servidor
        guard let url = await APIClient.shared.downloadPlanoURL(planoId: plano.id) else { return }
        do {
            // Necesitamos añadir el token de auth
            let token = await getToken()
            var request = URLRequest(url: url)
            if let token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            let (data, _) = try await URLSession.shared.data(for: request)
            await MainActor.run { pdfData = data }
        } catch {}
    }

    private func getToken() async -> String? {
        // El token se gestiona en APIClient pero necesitamos accederlo para URLRequest directa
        // En una implementación completa esto se refactorizaría
        return nil // El token ya está en el APIClient
    }

    private func saveAnnotation() async {
        isSaving = true
        defer { Task { @MainActor in isSaving = false } }

        guard let originalData = pdfData,
              let pdfDoc = PDFDocument(data: originalData) else { return }

        // Renderizar PDF con anotaciones PencilKit superpuestas
        let drawing = canvasView.drawing
        guard let annotatedPDF = renderAnnotatedPDF(document: pdfDoc, drawing: drawing) else {
            await MainActor.run { saveError = "Error al generar PDF anotado" }
            return
        }

        do {
            _ = try await APIClient.shared.uploadAnotacion(planoId: plano.id, pdfData: annotatedPDF)
        } catch {
            await MainActor.run { saveError = error.localizedDescription }
        }
    }

    /// Fusiona el PDF original con el dibujo PencilKit generando un nuevo PDF.
    private func renderAnnotatedPDF(document: PDFDocument, drawing: PKDrawing) -> Data? {
        let renderer = UIGraphicsPDFRenderer(bounds: .zero)
        return renderer.pdfData { context in
            for i in 0..<document.pageCount {
                guard let page = document.page(at: i) else { continue }
                let bounds = page.bounds(for: .mediaBox)

                context.beginPage(withBounds: bounds, pageInfo: [:])
                let cgContext = context.cgContext

                // Dibujar la página original
                cgContext.saveGState()
                cgContext.translateBy(x: 0, y: bounds.height)
                cgContext.scaleBy(x: 1, y: -1)
                page.draw(with: .mediaBox, to: cgContext)
                cgContext.restoreGState()

                // Superponer el dibujo PencilKit
                let image = drawing.image(from: bounds, scale: UIScreen.main.scale)
                image.draw(in: bounds)
            }
        }
    }
}

// MARK: - UIKit bridge para PDFView + PKCanvasView

struct PDFAnnotationView: UIViewRepresentable {
    let pdfData: Data
    @Binding var canvasView: PKCanvasView
    @Binding var isToolPickerVisible: Bool

    func makeUIView(context: Context) -> UIView {
        let container = UIView()

        // PDFView
        let pdfView = PDFView()
        pdfView.document = PDFDocument(data: pdfData)
        pdfView.autoScales = true
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(pdfView)

        // PencilKit canvas superpuesto
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .pencilOnly
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(canvasView)

        NSLayoutConstraint.activate([
            pdfView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            pdfView.topAnchor.constraint(equalTo: container.topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            canvasView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            canvasView.topAnchor.constraint(equalTo: container.topAnchor),
            canvasView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        canvasView.isUserInteractionEnabled = isToolPickerVisible

        if isToolPickerVisible {
            let toolPicker = PKToolPicker()
            toolPicker.setVisible(true, forFirstResponder: canvasView)
            canvasView.becomeFirstResponder()
        }
    }
}
