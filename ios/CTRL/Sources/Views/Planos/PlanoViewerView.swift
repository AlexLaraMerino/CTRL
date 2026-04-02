import SwiftUI
import PDFKit
import PencilKit

/// Visor de plano PDF con anotaciones PencilKit. Se presenta a pantalla completa.
struct PlanoViewerView: View {
    let plano: Plano

    @State private var pdfData: Data?
    @State private var isDrawingMode = false
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var coordinator = PDFCanvasCoordinator()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let data = pdfData {
                    PDFCanvasRepresentable(
                        pdfData: data,
                        isDrawingMode: isDrawingMode,
                        coordinator: coordinator
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
                        coordinator.hideToolPicker()
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
                            Image(systemName: "square.and.arrow.down")
                                .font(.title2)
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
            await MainActor.run { pdfData = data }
        } catch {}
    }

    private func saveAnnotation() async {
        isSaving = true

        guard let originalData = pdfData,
              let pdfDoc = PDFDocument(data: originalData) else {
            isSaving = false
            return
        }

        let drawing = coordinator.canvasView.drawing
        guard let annotatedPDF = renderAnnotatedPDF(document: pdfDoc, drawing: drawing) else {
            saveError = "Error al generar PDF anotado"
            isSaving = false
            return
        }

        do {
            _ = try await APIClient.shared.uploadAnotacion(planoId: plano.id, pdfData: annotatedPDF)
            await MainActor.run { isSaving = false }
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

                cgContext.saveGState()
                cgContext.translateBy(x: 0, y: bounds.height)
                cgContext.scaleBy(x: 1, y: -1)
                page.draw(with: .mediaBox, to: cgContext)
                cgContext.restoreGState()

                let image = drawing.image(from: bounds, scale: UIScreen.main.scale)
                image.draw(in: bounds)
            }
        }
    }
}

// MARK: - Coordinator que retiene el PKToolPicker

class PDFCanvasCoordinator {
    let canvasView = PKCanvasView()
    let toolPicker = PKToolPicker()

    func showToolPicker() {
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()
    }

    func hideToolPicker() {
        toolPicker.setVisible(false, forFirstResponder: canvasView)
        toolPicker.removeObserver(canvasView)
        canvasView.resignFirstResponder()
    }
}

// MARK: - UIKit bridge

struct PDFCanvasRepresentable: UIViewRepresentable {
    let pdfData: Data
    let isDrawingMode: Bool
    let coordinator: PDFCanvasCoordinator

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .systemBackground

        // PDFView
        let pdfView = PDFView()
        pdfView.document = PDFDocument(data: pdfData)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displaysPageBreaks = true
        pdfView.tag = 100
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(pdfView)

        // PencilKit canvas superpuesto
        let canvas = coordinator.canvasView
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .pencilOnly
        canvas.isUserInteractionEnabled = false
        canvas.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(canvas)

        NSLayoutConstraint.activate([
            pdfView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            pdfView.topAnchor.constraint(equalTo: container.topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            canvas.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            canvas.topAnchor.constraint(equalTo: container.topAnchor),
            canvas.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        let canvas = coordinator.canvasView
        canvas.isUserInteractionEnabled = isDrawingMode

        if isDrawingMode {
            coordinator.showToolPicker()
        } else {
            coordinator.hideToolPicker()
        }
    }
}
