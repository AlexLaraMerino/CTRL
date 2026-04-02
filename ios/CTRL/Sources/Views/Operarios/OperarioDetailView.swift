import SwiftUI

struct OperarioDetailView: View {
    let operario: Operario
    let dailyState: DailyStateManager

    @State private var asignaciones: [Asignacion] = []
    @State private var historial: [HistorialEntry] = []
    @State private var weekOffset = 0
    @State private var showEditForm = false
    @Environment(\.dismiss) private var dismiss

    private var weekStart: Date {
        let cal = Calendar.current
        let base = cal.date(byAdding: .weekOfYear, value: weekOffset, to: .now)!
        return cal.dateInterval(of: .weekOfYear, for: base)?.start ?? base
    }

    private var weekDays: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let shortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "EEE d"
        return f
    }()

    var body: some View {
        NavigationStack {
            List {
                // Datos personales
                Section("Datos personales") {
                    LabeledContent("Nombre", value: operario.nombre)
                    if let tel = operario.telefono {
                        LabeledContent("Teléfono", value: tel)
                    }
                    if let esp = operario.especialidades {
                        LabeledContent("Especialidades") {
                            HStack {
                                ForEach(esp, id: \.self) { e in
                                    Text(e)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(.blue.opacity(0.1), in: Capsule())
                                }
                            }
                        }
                    }
                    LabeledContent("Estado", value: operario.activo ? "Activo" : "Inactivo")
                    if let notas = operario.notas, !notas.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notas")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(notas)
                        }
                    }
                }

                // Calendario semanal
                Section {
                    HStack {
                        Button { weekOffset -= 1; Task { await loadAsignaciones() } } label: {
                            Image(systemName: "chevron.left")
                        }
                        Spacer()
                        Text("Semana del \(Self.shortFormatter.string(from: weekStart))")
                            .font(.subheadline.bold())
                        Spacer()
                        Button { weekOffset += 1; Task { await loadAsignaciones() } } label: {
                            Image(systemName: "chevron.right")
                        }
                    }

                    ForEach(weekDays, id: \.self) { day in
                        let dateStr = Self.dateFormatter.string(from: day)
                        let asig = asignaciones.first { $0.fecha == dateStr && $0.activo }

                        HStack {
                            Text(Self.shortFormatter.string(from: day).capitalized)
                                .font(.subheadline)
                                .frame(width: 60, alignment: .leading)

                            if let a = asig {
                                if a.esRuta {
                                    Label("Ruta", systemImage: "figure.walk")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                } else if let obraId = a.obraId,
                                          let obra = dailyState.obras.first(where: { $0.id == obraId }) {
                                    Text(obra.nombre)
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                } else {
                                    Text("Posición libre")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            } else {
                                Text("—")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                } header: {
                    Text("Calendario semanal")
                }

                // Historial
                Section("Historial") {
                    if historial.isEmpty {
                        Text("Sin entradas")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(historial.prefix(15)) { entry in
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
            .navigationTitle(operario.nombre)
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
                OperarioFormView(existingOperario: operario) {
                    Task { await dailyState.loadDay() }
                }
            }
            .task { await loadAll() }
        }
    }

    private func loadAll() async {
        await loadAsignaciones()
        do {
            historial = try await APIClient.shared.historialOperario(operarioId: operario.id)
        } catch {}
    }

    private func loadAsignaciones() async {
        let desde = Self.dateFormatter.string(from: weekStart)
        let hasta = Self.dateFormatter.string(from: weekDays.last ?? weekStart)
        do {
            asignaciones = try await APIClient.shared.listOperarioAsignaciones(
                operarioId: operario.id, desde: desde, hasta: hasta
            )
        } catch {}
    }
}
