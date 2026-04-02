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
        guard let annotatedPDF = renderAnnotatedPDF(document: pdfDoc, drawing: drawing, canvasSize: await MainActor.run { vc.canvasView.bounds.size }) else {
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

    private func renderAnnotatedPDF(document: PDFDocument, drawing: PKDrawing, canvasSize: CGSize) -> Data? {
        // Calcular la altura total de todas las páginas para mapear las coordenadas del canvas
        var totalHeight: CGFloat = 0
        var pageRects: [(rect: CGRect, pdfBounds: CGRect)] = []

        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            let pdfBounds = page.bounds(for: .mediaBox)
            let scale = canvasSize.width / pdfBounds.width
            let displayHeight = pdfBounds.height * scale
            let pageRect = CGRect(x: 0, y: totalHeight, width: canvasSize.width, height: displayHeight)
            pageRects.append((rect: pageRect, pdfBounds: pdfBounds))
            totalHeight += displayHeight
        }

        let renderer = UIGraphicsPDFRenderer(bounds: .zero)
        return renderer.pdfData { context in
            for i in 0..<document.pageCount {
                guard let page = document.page(at: i) else { continue }
                let pdfBounds = page.bounds(for: .mediaBox)

                context.beginPage(withBounds: pdfBounds, pageInfo: [:])
                let cgContext = context.cgContext

                cgContext.saveGState()
                cgContext.translateBy(x: 0, y: pdfBounds.height)
                cgContext.scaleBy(x: 1, y: -1)
                page.draw(with: .mediaBox, to: cgContext)
                cgContext.restoreGState()

                // Extraer solo la porción del dibujo que corresponde a esta página
                if i < pageRects.count {
                    let pr = pageRects[i]
                    let image = drawing.image(from: pr.rect, scale: UIScreen.main.scale)
                    image.draw(in: pdfBounds)
                }
            }
        }
    }
}

// MARK: - UIKit ViewController

class PDFCanvasViewController: UIViewController {
    let pdfView = PDFView()
    let canvasView = PKCanvasView()
    private let toolPicker = PKToolPicker()
    private let pdfData: Data
    private var hasSetup = false

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

        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: view.topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            pdfView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !hasSetup {
            hasSetup = true
            embedCanvas()
        }
    }

    /// Inyecta el PKCanvasView dentro del scrollView interno del PDFView
    /// para que el dibujo se desplace junto con las páginas.
    private func embedCanvas() {
        // PDFView contiene un UIScrollView internamente
        guard let scrollView = findScrollView(in: pdfView) else { return }
        guard let contentView = scrollView.subviews.first else { return }

        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        canvasView.isUserInteractionEnabled = false
        canvasView.frame = contentView.bounds
        canvasView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(canvasView)

        // Observar cambios de tamaño del contenido
        scrollView.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "contentSize" {
            guard let scrollView = findScrollView(in: pdfView),
                  let contentView = scrollView.subviews.first else { return }
            canvasView.frame = contentView.bounds
        }
    }

    private func findScrollView(in view: UIView) -> UIScrollView? {
        if let sv = view as? UIScrollView { return sv }
        for sub in view.subviews {
            if let found = findScrollView(in: sub) { return found }
        }
        return nil
    }

    func setDrawingMode(_ enabled: Bool) {
        canvasView.isUserInteractionEnabled = enabled

        // Deshabilitar el scroll del PDF cuando se dibuja
        if let scrollView = findScrollView(in: pdfView) {
            scrollView.isScrollEnabled = !enabled
        }

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

    deinit {
        if let scrollView = findScrollView(in: pdfView) {
            scrollView.removeObserver(self, forKeyPath: "contentSize")
        }
    }
}

// MARK: - Wrapper

struct PDFCanvasWrapper: UIViewControllerRepresentable {
    let viewController: PDFCanvasViewController

    func makeUIViewController(context: Context) -> PDFCanvasViewController {
        viewController
    }

    func updateUIViewController(_ vc: PDFCanvasViewController, context: Context) {}
}
