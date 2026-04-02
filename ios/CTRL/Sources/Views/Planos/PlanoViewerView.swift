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
    @State private var pdfCanvasVC: SinglePagePDFController?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if pdfData != nil, let vc = pdfCanvasVC {
                    SinglePagePDFWrapper(viewController: vc)
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
                pdfCanvasVC = SinglePagePDFController(pdfData: data)
            }
        } catch {}
    }

    private func saveAnnotation() async {
        guard let vc = pdfCanvasVC, let originalData = pdfData,
              let pdfDoc = PDFDocument(data: originalData) else {
            isSaving = false
            return
        }

        isSaving = true
        saveSuccess = false

        let drawings = await MainActor.run { vc.allDrawings() }

        guard let annotatedPDF = renderAnnotatedPDF(document: pdfDoc, drawings: drawings) else {
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

    private func renderAnnotatedPDF(document: PDFDocument, drawings: [Int: PKDrawing]) -> Data? {
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

                if let drawing = drawings[i] {
                    let image = drawing.image(from: bounds, scale: UIScreen.main.scale)
                    image.draw(in: bounds)
                }
            }
        }
    }
}

// MARK: - Single page PDF + PencilKit controller

class SinglePagePDFController: UIViewController {
    private let pdfDocument: PDFDocument
    private let pdfView = PDFView()
    let canvasView = PKCanvasView()
    private let toolPicker = PKToolPicker()
    private let pageLabel = UILabel()
    private let prevButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)

    private var currentPage = 0
    private var pageDrawings: [Int: PKDrawing] = [:]

    var pageCount: Int { pdfDocument.pageCount }

    init(pdfData: Data) {
        self.pdfDocument = PDFDocument(data: pdfData) ?? PDFDocument()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        setupPDFView()
        setupCanvas()
        setupPageControls()
        showPage(0)
    }

    private func setupPDFView() {
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displaysPageBreaks = false
        pdfView.backgroundColor = .systemBackground
        pdfView.isUserInteractionEnabled = true
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pdfView)

        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: view.topAnchor),
            pdfView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pdfView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50),
        ])
    }

    private func setupCanvas() {
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        canvasView.isUserInteractionEnabled = false
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(canvasView)

        NSLayoutConstraint.activate([
            canvasView.topAnchor.constraint(equalTo: pdfView.topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: pdfView.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: pdfView.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: pdfView.bottomAnchor),
        ])
    }

    private func setupPageControls() {
        let bar = UIView()
        bar.backgroundColor = .secondarySystemBackground
        bar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bar)

        prevButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        prevButton.addTarget(self, action: #selector(prevPage), for: .touchUpInside)
        prevButton.translatesAutoresizingMaskIntoConstraints = false

        nextButton.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        nextButton.addTarget(self, action: #selector(nextPage), for: .touchUpInside)
        nextButton.translatesAutoresizingMaskIntoConstraints = false

        pageLabel.textAlignment = .center
        pageLabel.font = .systemFont(ofSize: 14, weight: .medium)
        pageLabel.translatesAutoresizingMaskIntoConstraints = false

        bar.addSubview(prevButton)
        bar.addSubview(pageLabel)
        bar.addSubview(nextButton)

        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bar.heightAnchor.constraint(equalToConstant: 50),

            prevButton.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 20),
            prevButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            prevButton.widthAnchor.constraint(equalToConstant: 44),
            prevButton.heightAnchor.constraint(equalToConstant: 44),

            nextButton.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -20),
            nextButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 44),
            nextButton.heightAnchor.constraint(equalToConstant: 44),

            pageLabel.centerXAnchor.constraint(equalTo: bar.centerXAnchor),
            pageLabel.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
        ])
    }

    private func showPage(_ index: Int) {
        // Guardar dibujo actual
        pageDrawings[currentPage] = canvasView.drawing

        currentPage = index

        // Mostrar la página
        if let page = pdfDocument.page(at: index) {
            pdfView.go(to: page)
        }

        // Restaurar dibujo de la nueva página
        canvasView.drawing = pageDrawings[index] ?? PKDrawing()

        // Actualizar controles
        pageLabel.text = "Página \(index + 1) de \(pageCount)"
        prevButton.isEnabled = index > 0
        nextButton.isEnabled = index < pageCount - 1
    }

    @objc private func prevPage() {
        if currentPage > 0 { showPage(currentPage - 1) }
    }

    @objc private func nextPage() {
        if currentPage < pageCount - 1 { showPage(currentPage + 1) }
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

    /// Devuelve todos los dibujos indexados por número de página.
    func allDrawings() -> [Int: PKDrawing] {
        // Guardar el de la página actual
        pageDrawings[currentPage] = canvasView.drawing
        return pageDrawings
    }
}

// MARK: - Wrapper

struct SinglePagePDFWrapper: UIViewControllerRepresentable {
    let viewController: SinglePagePDFController

    func makeUIViewController(context: Context) -> SinglePagePDFController {
        viewController
    }

    func updateUIViewController(_ vc: SinglePagePDFController, context: Context) {}
}
