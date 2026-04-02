import SwiftUI
import UniformTypeIdentifiers

struct ObraDetailView: View {
    let obra: Obra
    let dailyState: DailyStateManager

    @State private var planos: [Plano] = []
    @State private var historial: [HistorialEntry] = []
    @State private var operariosHoy: [Operario] = []
    @State private var selectedPlano: Plano?
    @State private var showEditForm = false
    @State private var showFilePicker = false
    @State private var isUploading = false
    @State private var uploadError: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Datos generales
                Section("Datos generales") {
                    LabeledContent("Nombre", value: obra.nombre)
                    if let dir = obra.direccion {
                        LabeledContent("Dirección", value: dir)
                    }
                    LabeledContent("Estado", value: obra.estado.capitalized)
                    if let tipos = obra.tiposInstalacion {
                        LabeledContent("Tipos") {
                            HStack {
                                ForEach(tipos, id: \.self) { t in
                                    Text(t)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(.blue.opacity(0.1), in: Capsule())
                                }
                            }
                        }
                    }
                    if let inicio = obra.fechaInicio {
                        LabeledContent("Inicio", value: inicio)
                    }
                    if let fin = obra.fechaFinPrevista {
                        LabeledContent("Fin previsto", value: fin)
                    }
                    if let notas = obra.notas, !notas.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notas")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(notas)
                                .font(.body)
                        }
                    }
                }

                // Operarios asignados hoy
                Section("Operarios hoy") {
                    if operariosHoy.isEmpty {
                        Text("Sin operarios asignados")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(operariosHoy) { op in
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(.blue.opacity(0.2))
                                        .frame(width: 32, height: 32)
                                    Text(op.initials)
                                        .font(.caption2.bold())
                                        .foregroundStyle(.blue)
                                }
                                Text(op.nombre)

                                Spacer()

                                Button {
                                    Task { await removeOperario(op) }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                        .font(.title3)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }

                // Planos
                Section("Planos") {
                    if planos.isEmpty && !isUploading {
                        Text("Sin planos")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(planos) { plano in
                        HStack {
                            Button {
                                selectedPlano = plano
                            } label: {
                                HStack {
                                    Image(systemName: "doc.richtext")
                                    VStack(alignment: .leading) {
                                        Text(plano.nombre)
                                            .font(.subheadline)
                                        Text("v\(plano.version)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.borderless)

                            Button {
                                Task { await deletePlano(plano) }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    if isUploading {
                        HStack {
                            ProgressView()
                            Text("Subiendo plano...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let error = uploadError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button {
                        showFilePicker = true
                    } label: {
                        Label("Subir plano PDF", systemImage: "doc.badge.plus")
                    }
                    .disabled(isUploading)
                }

                // Historial
                Section("Historial") {
                    if historial.isEmpty {
                        Text("Sin entradas")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(historial.prefix(10)) { entry in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.descripcion)
                                    .font(.caption)
                                HStack {
                                    Text(entry.usuario)
                                    Text("·")
                                    Text(entry.timestamp)
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(obra.nombre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Editar") { showEditForm = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .sheet(isPresented: $showEditForm) {
                ObraFormView(existingObra: obra) {
                    Task { await dailyState.loadDay() }
                }
            }
            .fullScreenCover(item: $selectedPlano) { plano in
                PlanoViewerView(plano: plano)
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                Task { await handleFileImport(result) }
            }
            .task { await loadData() }
        }
    }

    private func loadData() async {
        do {
            async let planosTask = APIClient.shared.listPlanos(obraId: obra.id)
            async let historialTask = APIClient.shared.historialObra(obraId: obra.id)

            let (p, h) = try await (planosTask, historialTask)
            await MainActor.run {
                planos = p
                historial = h
                operariosHoy = dailyState.operariosInObra(obra.id)
            }
        } catch {}
    }

    private func removeOperario(_ operario: Operario) async {
        // Buscar la asignación activa de este operario en esta obra hoy
        guard let asignacion = dailyState.asignaciones.first(where: {
            $0.operarioId == operario.id && $0.obraId == obra.id && $0.activo
        }) else { return }

        do {
            try await APIClient.shared.deleteAsignacion(id: asignacion.id)
            await dailyState.loadDay()
            await MainActor.run {
                operariosHoy = dailyState.operariosInObra(obra.id)
            }
        } catch {}
    }

    private func handleFileImport(_ result: Result<[URL], Error>) async {
        guard case .success(let urls) = result, let url = urls.first else {
            await MainActor.run { uploadError = "No se pudo seleccionar el archivo" }
            return
        }

        // Obtener acceso al fichero (security-scoped resource)
        guard url.startAccessingSecurityScopedResource() else {
            await MainActor.run { uploadError = "Sin acceso al archivo" }
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            let filename = url.lastPathComponent

            await MainActor.run {
                isUploading = true
                uploadError = nil
            }

            _ = try await APIClient.shared.uploadPlano(
                obraId: obra.id,
                fileData: data,
                filename: filename
            )

            // Recargar la lista de planos
            let updatedPlanos = try await APIClient.shared.listPlanos(obraId: obra.id)
            await MainActor.run {
                planos = updatedPlanos
                isUploading = false
            }
        } catch {
            await MainActor.run {
                uploadError = error.localizedDescription
                isUploading = false
            }
        }
    }

    private func deletePlano(_ plano: Plano) async {
        do {
            try await APIClient.shared.deletePlano(planoId: plano.id)
            let updatedPlanos = try await APIClient.shared.listPlanos(obraId: obra.id)
            await MainActor.run { planos = updatedPlanos }
        } catch {}
    }
}
