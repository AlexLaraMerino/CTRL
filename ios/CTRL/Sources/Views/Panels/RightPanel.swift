import SwiftUI

struct RightPanel: View {
    @Binding var tab: MainView.RightPanelTab
    let dailyState: DailyStateManager
    let onClose: () -> Void
    let onObraSelected: (Obra) -> Void
    let onOperarioSelected: (Operario) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Cabecera con tabs
            HStack {
                Picker("Panel", selection: $tab) {
                    Text("Obras").tag(MainView.RightPanelTab.obras)
                    Text("Operarios").tag(MainView.RightPanelTab.operarios)
                }
                .pickerStyle(.segmented)

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()

            Divider()

            // Contenido según tab
            switch tab {
            case .obras:
                ObrasListPanel(
                    obras: dailyState.obras,
                    dailyState: dailyState,
                    onSelected: onObraSelected
                )
            case .operarios:
                OperariosListPanel(
                    operarios: dailyState.operarios,
                    dailyState: dailyState,
                    onSelected: onOperarioSelected
                )
            }
        }
    }
}

// MARK: - Lista de obras

struct ObrasListPanel: View {
    let obras: [Obra]
    let dailyState: DailyStateManager
    let onSelected: (Obra) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(obras) { obra in
                    ObraCard(obra: obra, operarioCount: dailyState.operarioCount(for: obra.id))
                        .onTapGesture { onSelected(obra) }
                }
            }
            .padding()
        }
    }
}

struct ObraCard: View {
    let obra: Obra
    let operarioCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(obra.nombre)
                    .font(.subheadline.bold())
                Spacer()
                if operarioCount > 0 {
                    Text("×\(operarioCount)")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.15), in: Capsule())
                }
            }

            if let dir = obra.direccion {
                Text(dir)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                estadoBadge(obra.estado)
                if let tipos = obra.tiposInstalacion {
                    ForEach(tipos, id: \.self) { tipo in
                        Text(tipo)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.gray.opacity(0.15), in: Capsule())
                    }
                }
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    private func estadoBadge(_ estado: String) -> some View {
        Text(estado)
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(colorForEstado(estado), in: Capsule())
    }

    private func colorForEstado(_ estado: String) -> Color {
        switch estado {
        case "activa": return .green
        case "pausada": return .orange
        case "finalizada": return .gray
        default: return .blue
        }
    }
}

// MARK: - Lista de operarios

struct OperariosListPanel: View {
    let operarios: [Operario]
    let dailyState: DailyStateManager
    let onSelected: (Operario) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(operarios) { operario in
                    OperarioRow(operario: operario, asignacion: asignacionForOperario(operario.id))
                        .onTapGesture { onSelected(operario) }
                        .draggable(operario.id) // Permite arrastrar al mapa
                }
            }
            .padding()
        }
    }

    private func asignacionForOperario(_ id: String) -> Asignacion? {
        dailyState.asignaciones.first { $0.operarioId == id && $0.activo }
    }
}

struct OperarioRow: View {
    let operario: Operario
    let asignacion: Asignacion?

    var body: some View {
        HStack(spacing: 12) {
            // Avatar con iniciales
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                Text(operario.initials)
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(operario.nombre)
                    .font(.subheadline.bold())

                if let asig = asignacion {
                    if asig.esRuta {
                        Text("En ruta")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else if asig.obraId != nil {
                        Text("Asignado")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    } else {
                        Text("Posición libre")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } else {
                    Text("Sin asignar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(10)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }
}
