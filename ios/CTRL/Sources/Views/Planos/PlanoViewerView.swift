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

        // Recoger los dibujos de cada página
        let pageDrawings = await MainActor.run { coord.pageDrawings }
        guard let annotatedPDF = renderAnnotatedPDF(document: pdfDoc, drawings: pageDrawings) else {
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

    private func renderAnnotatedPDF(document: PDFDocument, drawings: [Int: PKDrawing]) -> Data? {
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

                // Superponer el dibujo de esta página
                if let drawing = drawings[i] {
                    let image = drawing.image(from: bounds, scale: UIScreen.main.scale)
                    image.draw(in: bounds)
                }
            }
        }
    }
}

// MARK: - Coordinator: un PKCanvasView por página

class PDFCanvasCoordinator {
    var canvases: [Int: PKCanvasView] = [:]
    let toolPicker = PKToolPicker()
    private(set) var pdfView: PDFView?

    /// Dibujos indexados por número de página.
    var pageDrawings: [Int: PKDrawing] {
        canvases.mapValues { $0.drawing }
    }

    func setup(pdfView: PDFView, pageCount: Int) {
        self.pdfView = pdfView

        // Crear un canvas por cada página
        for i in 0..<pageCount {
            guard let page = pdfView.document?.page(at: i) else { continue }
            let pageBounds = page.bounds(for: .mediaBox)

            let canvas = PKCanvasView()
            canvas.backgroundColor = .clear
            canvas.isOpaque = false
            canvas.drawingPolicy = .pencilOnly
            canvas.isUserInteractionEnabled = false

            // Obtener la vista de la página y superponer el canvas
            if let pageView = pdfView.pageView(for: page) {
                canvas.frame = CGRect(origin: .zero, size: pageView.bounds.size)
                canvas.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                pageView.addSubview(canvas)
                canvases[i] = canvas
            }
        }
    }

    func setDrawingMode(_ enabled: Bool) {
        for canvas in canvases.values {
            canvas.isUserInteractionEnabled = enabled
        }
        if enabled {
            showToolPicker()
        } else {
            hideToolPicker()
        }
    }

    func showToolPicker() {
        guard let firstCanvas = canvases.values.first else { return }
        for canvas in canvases.values {
            toolPicker.addObserver(canvas)
        }
        toolPicker.setVisible(true, forFirstResponder: firstCanvas)
        firstCanvas.becomeFirstResponder()
    }

    func hideToolPicker() {
        for canvas in canvases.values {
            toolPicker.setVisible(false, forFirstResponder: canvas)
            toolPicker.removeObserver(canvas)
            canvas.resignFirstResponder()
        }
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

        // Esperar a que el layout esté listo para añadir los canvas
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let pageCount = pdfView.document?.pageCount ?? 0
            coordinator.setup(pdfView: pdfView, pageCount: pageCount)
        }

        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        coordinator.setDrawingMode(isDrawingMode)
    }
}
