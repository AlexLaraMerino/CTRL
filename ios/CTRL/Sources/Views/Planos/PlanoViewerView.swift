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
    @State private var pdfCanvasVC: PDFCanvasViewController?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if pdfData != nil, let vc = pdfCanvasVC {
                    PDFCanvasWrapper(viewController: vc)
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
                        pdfCanvasVC?.setDrawingMode(false)
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isDrawingMode.toggle()
                        pdfCanvasVC?.setDrawingMode(isDrawingMode)
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
                pdfCanvasVC = PDFCanvasViewController(pdfData: data)
            }
        } catch {}
    }

    private func saveAnnotation() async {
        guard let vc = pdfCanvasVC else { return }
        isSaving = true
        saveSuccess = false

        guard let originalData = pdfData,
              let pdfDoc = PDFDocument(data: originalData) else {
            isSaving = false
            return
        }

        let drawing = await MainActor.run { vc.canvasView.drawing }
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

// MARK: - UIKit ViewController para PDF + PencilKit sin interferencia de SwiftUI

class PDFCanvasViewController: UIViewController {
    let pdfView = PDFView()
    let canvasView = PKCanvasView()
    private let toolPicker = PKToolPicker()
    private let pdfData: Data

    init(pdfData: Data) {
        self.pdfData = pdfData
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()

        // PDF
        pdfView.document = PDFDocument(data: pdfData)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displaysPageBreaks = true
        pdfView.backgroundColor = .systemBackground
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pdfView)

        // Canvas superpuesto
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        canvasView.isUserInteractionEnabled = false
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(canvasView)

        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: view.topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            pdfView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            canvasView.topAnchor.constraint(equalTo: view.topAnchor),
            canvasView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            canvasView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    func setDrawingMode(_ enabled: Bool) {
        canvasView.isUserInteractionEnabled = enabled
        if enabled {
            toolPicker.addObserver(canvasView)
            toolPicker.setVisible(true, forFirstResponder: canvasView)
            canvasView.becomeFirstResponder()
        } else {
            toolPicker.setVisible(false, forFirstResponder: canvasView)
            toolPicker.removeObserver(canvasView)
            canvasView.resignFirstResponder()
        }
    }
}

// MARK: - UIViewControllerRepresentable wrapper

struct PDFCanvasWrapper: UIViewControllerRepresentable {
    let viewController: PDFCanvasViewController

    func makeUIViewController(context: Context) -> PDFCanvasViewController {
        viewController
    }

    func updateUIViewController(_ vc: PDFCanvasViewController, context: Context) {
        // No hacer nada aquí — toda la lógica se maneja desde los botones
    }
}
