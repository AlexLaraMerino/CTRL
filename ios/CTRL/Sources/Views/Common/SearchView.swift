import SwiftUI
import MapKit

struct SearchView: View {
    let dailyState: DailyStateManager
    let onObraSelected: (Obra) -> Void
    let onOperarioSelected: (Operario) -> Void
    let onCenterMap: (CLLocationCoordinate2D) -> Void

    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    private var filteredObras: [Obra] {
        guard !query.isEmpty else { return dailyState.obras }
        let q = query.lowercased()
        return dailyState.obras.filter {
            $0.nombre.lowercased().contains(q) ||
            ($0.direccion?.lowercased().contains(q) ?? false) ||
            ($0.tiposInstalacion?.contains(where: { $0.lowercased().contains(q) }) ?? false)
        }
    }

    private var filteredOperarios: [Operario] {
        guard !query.isEmpty else { return dailyState.operarios }
        let q = query.lowercased()
        return dailyState.operarios.filter {
            $0.nombre.lowercased().contains(q) ||
            ($0.especialidades?.contains(where: { $0.lowercased().contains(q) }) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !filteredObras.isEmpty {
                    Section("Obras") {
                        ForEach(filteredObras) { obra in
                            Button {
                                dismiss()
                                if let coord = obra.coordinate {
                                    onCenterMap(coord)
                                }
                                onObraSelected(obra)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "building.2.fill")
                                        .foregroundStyle(.blue)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(obra.nombre)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.primary)
                                        if let dir = obra.direccion {
                                            Text(dir)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()

                                    if obra.coordinate != nil {
                                        Image(systemName: "location.fill")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }

                if !filteredOperarios.isEmpty {
                    Section("Operarios") {
                        ForEach(filteredOperarios) { operario in
                            Button {
                                dismiss()
                                onOperarioSelected(operario)
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(.blue.opacity(0.2))
                                            .frame(width: 32, height: 32)
                                        Text(operario.initials)
                                            .font(.caption2.bold())
                                            .foregroundStyle(.blue)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(operario.nombre)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.primary)
                                        if let esp = operario.especialidades, !esp.isEmpty {
                                            Text(esp.joined(separator: ", "))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                if filteredObras.isEmpty && filteredOperarios.isEmpty && !query.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar obras o operarios")
            .navigationTitle("Buscar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}
