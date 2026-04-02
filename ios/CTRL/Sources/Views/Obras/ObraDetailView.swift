import SwiftUI

struct ObraDetailView: View {
    let obra: Obra
    let dailyState: DailyStateManager

    @State private var planos: [Plano] = []
    @State private var historial: [HistorialEntry] = []
    @State private var operariosHoy: [Operario] = []
    @State private var selectedPlano: Plano?
    @State private var showEditForm = false
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
                            }
                        }
                    }
                }

                // Planos
                Section("Planos") {
                    if planos.isEmpty {
                        Text("Sin planos")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(planos) { plano in
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
                        }
                    }
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
            .sheet(item: $selectedPlano) { plano in
                PlanoViewerView(plano: plano)
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
}
