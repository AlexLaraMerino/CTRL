import SwiftUI
import PDFKit
import PencilKit

struct PlanoViewerView: View {
    let plano: Plano

    @State private var pdfData: Data?
    @State private var isDrawingMode = false
    @State private var isSaving = false
    @State private var saveSuccess = false
    @State private var saveError: String?
    @State private var coordinator: PDFCanvasCoordinator?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let data = pdfData, let coord = coordinator {
                    EmbeddedPDFCanvas(
                        pdfData: data,
                        isDrawingMode: isDrawingMode,
                        coordinator: coord
                    )
                    .ignoresSafeArea(edges: .bottom)
                } else {
                    VStack {
                        Spacer()
                        ProgressView("Cargando plano...")
                        Spacer()
                    }
                }
            }
            .navigationTitle(plano.nombre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") {
                        coordinator?.hideToolPicker()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isDrawingMode.toggle()
                    } label: {
                        Image(systemName: isDrawingMode ? "pencil.circle.fill" : "pencil.circle")
                            .font(.title2)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await saveAnnotation() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Image(systemName: saveSuccess ? "checkmark.circle.fill" : "square.and.arrow.down")
                                .font(.title2)
                                .foregroundStyle(saveSuccess ? .green : .blue)
                        }
                    }
                    .disabled(isSaving || pdfData == nil)
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
        guard let url = await APIClient.shared.downloadPlanoURL(planoId: plano.id) else { return }
        do {
            let token = await APIClient.shared.getToken()
            var request = URLRequest(url: url)
            if let token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            let (data, _) = try await URLSession.shared.data(for: request)
            await MainActor.run {
                pdfData = data
                coordinator = PDFCanvasCoordinator()
            }
        } catch {}
    }

    private func saveAnnotation() async {
        guard let coord = coordinator else { return }
        isSaving = true
        saveSuccess = false

        guard let originalData = pdfData,
              let pdfDoc = PDFDocument(data: originalData) else {
            isSaving = false
            return
        }

        let drawing = await MainActor.run { coord.drawing }
        guard let annotatedPDF = renderAnnotatedPDF(document: pdfDoc, drawing: drawing) else {
            saveError = "Error al generar PDF anotado"
            isSaving = false
            return
        }

        do {
            _ = try await APIClient.shared.uploadAnotacion(planoId: plano.id, pdfData: annotatedPDF)
            await MainActor.run {
                isSaving = false
                saveSuccess = true
            }
            // Quitar el check después de 2 segundos
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run { saveSuccess = false }
        } catch {
            await MainActor.run {
                saveError = error.localizedDescription
                isSaving = false
            }
        }
    }

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

                // Superponer el dibujo completo (el canvas cubre todas las páginas)
                let image = drawing.image(from: bounds, scale: UIScreen.main.scale)
                image.draw(in: bounds)
            }
        }
    }
}

// MARK: - Coordinator: un canvas sobre el documentView del PDFView

class PDFCanvasCoordinator {
    let canvasView = PKCanvasView()
    let toolPicker = PKToolPicker()
    private(set) var pdfView: PDFView?

    /// El dibujo completo (cubre todas las páginas).
    var drawing: PKDrawing { canvasView.drawing }

    func setup(pdfView: PDFView) {
        self.pdfView = pdfView

        // Buscar el documentView (contenido scrollable del PDFView)
        guard let documentView = pdfView.subviews.first?.subviews.first else { return }

        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .pencilOnly
        canvasView.isUserInteractionEnabled = false
        canvasView.frame = documentView.bounds
        canvasView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        documentView.addSubview(canvasView)
    }

    func resizeCanvas() {
        guard let documentView = pdfView?.subviews.first?.subviews.first else { return }
        canvasView.frame = documentView.bounds
    }

    func setDrawingMode(_ enabled: Bool) {
        canvasView.isUserInteractionEnabled = enabled
        if enabled {
            showToolPicker()
        } else {
            hideToolPicker()
        }
    }

    func showToolPicker() {
        toolPicker.addObserver(canvasView)
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        canvasView.becomeFirstResponder()
    }

    func hideToolPicker() {
        toolPicker.setVisible(false, forFirstResponder: canvasView)
        toolPicker.removeObserver(canvasView)
        canvasView.resignFirstResponder()
    }
}

// MARK: - UIKit bridge

struct EmbeddedPDFCanvas: UIViewRepresentable {
    let pdfData: Data
    let isDrawingMode: Bool
    let coordinator: PDFCanvasCoordinator

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(data: pdfData)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displaysPageBreaks = true
        pdfView.backgroundColor = .systemBackground

        // Esperar a que el layout esté listo para añadir el canvas
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            coordinator.setup(pdfView: pdfView)
        }

        // Observar cambios de tamaño para reajustar el canvas
        NotificationCenter.default.addObserver(
            forName: .PDFViewPageChanged,
            object: pdfView,
            queue: .main
        ) { _ in
            coordinator.resizeCanvas()
        }

        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        coordinator.setDrawingMode(isDrawingMode)
        coordinator.resizeCanvas()
    }
}
