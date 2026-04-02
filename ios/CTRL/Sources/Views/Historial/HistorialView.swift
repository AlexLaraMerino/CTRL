import SwiftUI

struct HistorialView: View {
    @State private var entries: [HistorialEntry] = []
    @State private var filterTipo: String?
    @State private var isLoading = false
    @State private var selectedEntry: HistorialEntry?
    @Environment(\.dismiss) private var dismiss

    private let tipos = ["Todos", "obra", "operario", "asignacion", "plano"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filtros por tipo
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tipos, id: \.self) { tipo in
                            Button {
                                filterTipo = tipo == "Todos" ? nil : tipo
                                Task { await load() }
                            } label: {
                                Text(tipo == "Todos" ? "Todos" : tipo.capitalized)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        (filterTipo == tipo || (filterTipo == nil && tipo == "Todos"))
                                            ? .blue : .gray.opacity(0.2),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(
                                        (filterTipo == tipo || (filterTipo == nil && tipo == "Todos"))
                                            ? .white : .primary
                                    )
                            }
                        }
                    }
                    .padding()
                }

                Divider()

                // Lista de entradas
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if entries.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "Sin historial",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("No hay entradas de historial")
                    )
                    Spacer()
                } else {
                    List(entries) { entry in
                        Button {
                            selectedEntry = entry
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: iconForTipo(entry.tipoAccion))
                                    .foregroundStyle(colorForTipo(entry.tipoAccion))
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.descripcion)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)

                                    HStack {
                                        Text(entry.usuario)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("·")
                                            .foregroundStyle(.secondary)
                                        Text(formatTimestamp(entry.timestamp))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Historial")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .sheet(item: $selectedEntry) { entry in
                HistorialDetailSheet(entry: entry)
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        do {
            entries = try await APIClient.shared.listHistorial(tipo: filterTipo, limit: 100)
        } catch {}
        isLoading = false
    }

    private func iconForTipo(_ tipo: String) -> String {
        switch tipo {
        case "obra": return "building.2.fill"
        case "operario": return "person.fill"
        case "asignacion": return "arrow.triangle.swap"
        case "plano": return "doc.richtext.fill"
        default: return "circle.fill"
        }
    }

    private func colorForTipo(_ tipo: String) -> Color {
        switch tipo {
        case "obra": return .blue
        case "operario": return .green
        case "asignacion": return .orange
        case "plano": return .purple
        default: return .gray
        }
    }

    private func formatTimestamp(_ ts: String) -> String {
        // Simplificado: extraer hora del timestamp ISO
        if let tIndex = ts.firstIndex(of: "T") {
            let time = ts[ts.index(after: tIndex)...]
            if let dotIndex = time.firstIndex(of: ".") {
                return String(time[..<dotIndex])
            }
            return String(time.prefix(8))
        }
        return ts
    }
}

// MARK: - Detalle de entrada de historial

struct HistorialDetailSheet: View {
    let entry: HistorialEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Acción") {
                    LabeledContent("Tipo", value: entry.tipoAccion.capitalized)
                    LabeledContent("Entidad", value: "\(entry.entidadTipo) / \(entry.entidadId)")
                    LabeledContent("Usuario", value: entry.usuario)
                    LabeledContent("Fecha", value: entry.timestamp)
                }

                Section("Descripción") {
                    Text(entry.descripcion)
                }

                if let antes = entry.datosAnteriores {
                    Section("Datos anteriores") {
                        Text(antes)
                            .font(.caption.monospaced())
                    }
                }

                if let nuevos = entry.datosNuevos {
                    Section("Datos nuevos") {
                        Text(nuevos)
                            .font(.caption.monospaced())
                    }
                }
            }
            .navigationTitle("Detalle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}
