import SwiftUI

struct CalendarPanel: View {
    let dailyState: DailyStateManager
    let onClose: () -> Void

    @State private var showConfirmCopy = false
    @State private var showConfirmExtend = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Cabecera
            HStack {
                Text("Calendario")
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)

            // Mini-calendario
            DatePicker(
                "Fecha",
                selection: Binding(
                    get: { dailyState.selectedDate },
                    set: { dailyState.goToDate($0) }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .environment(\.locale, Locale(identifier: "es_ES"))
            .padding(.horizontal, 8)

            Divider()

            // Acciones rápidas
            VStack(spacing: 10) {
                Button {
                    showConfirmCopy = true
                } label: {
                    Label("Copiar configuración de ayer", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .confirmationDialog("¿Copiar asignaciones de ayer?", isPresented: $showConfirmCopy) {
                    Button("Copiar") { Task { await dailyState.copyYesterday() } }
                    Button("Cancelar", role: .cancel) {}
                }

                Button {
                    showConfirmExtend = true
                } label: {
                    Label("Extender hoy a la semana", systemImage: "calendar.badge.plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .confirmationDialog("¿Extender a los días laborables restantes?", isPresented: $showConfirmExtend) {
                    Button("Extender") { Task { await dailyState.extendWeek() } }
                    Button("Cancelar", role: .cancel) {}
                }
            }
            .padding(.horizontal)

            Divider()

            // Últimos cambios
            VStack(alignment: .leading, spacing: 8) {
                Text("Últimos cambios")
                    .font(.subheadline.bold())
                    .padding(.horizontal)

                RecentChangesView(fecha: dailyState.dateString)
            }

            Spacer()
        }
    }
}

struct RecentChangesView: View {
    let fecha: String
    @State private var entries: [HistorialEntry] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if entries.isEmpty {
                Text("Sin cambios recientes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(entries.prefix(5)) { entry in
                    HStack(spacing: 8) {
                        Image(systemName: iconForTipo(entry.tipoAccion))
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text(entry.descripcion)
                            .font(.caption)
                            .lineLimit(2)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .task {
            do {
                entries = try await APIClient.shared.listHistorial(fecha: fecha, limit: 5)
            } catch {}
        }
    }

    private func iconForTipo(_ tipo: String) -> String {
        switch tipo {
        case "obra": return "building.2"
        case "operario": return "person"
        case "asignacion": return "arrow.triangle.swap"
        case "plano": return "doc.richtext"
        default: return "circle"
        }
    }
}
