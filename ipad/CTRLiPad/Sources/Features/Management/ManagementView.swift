import SwiftUI

struct ManagementView: View {
    @EnvironmentObject private var store: DailyBoardStore
    let onClose: () -> Void
    let onLogout: () -> Void

    var body: some View {
        ZStack {
            Color.ctrlBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    if store.managementSection != .home {
                        Button {
                            store.managementSection = .home
                            store.focusedWorkSiteId = nil
                        } label: {
                            Label("Atrás", systemImage: "chevron.left")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }

                switch store.managementSection {
                case .home:
                    ManagementHome(onClose: onClose, onLogout: onLogout)
                case .archive:
                    WorkSiteArchiveView()
                case .history:
                    WorkSiteHistoryView()
                }
            }
            .padding(28)
        }
    }
}

private struct ManagementHome: View {
    @EnvironmentObject private var store: DailyBoardStore
    let onClose: () -> Void
    let onLogout: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gestión")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    if let currentUser = store.currentUser {
                        Text("Usuario actual: \(currentUser.displayName)")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ctrlMuted)
                    }
                }

                Spacer()
            }

            VStack(spacing: 14) {
                ManagementCard(title: "Libreta", description: "Notas privadas tipo diario por fecha", icon: "book.closed.fill")
                ManagementCard(title: "Notas", description: "Diario, comentario de obra y comunicado interno", icon: "square.and.pencil")
                ManagementCard(title: "Tablón", description: "Comunicados internos recibidos por el usuario actual", icon: "tray.full.fill")
                ManagementCard(title: "Archivo", description: "Documentos y planos vinculados a las obras", icon: "folder.fill") {
                    store.managementSection = .archive
                }
                ManagementCard(title: "Historial", description: "Eventos relevantes registrados por obra", icon: "clock.arrow.circlepath") {
                    store.managementSection = .history
                }
                ManagementCard(title: "Reservado", description: "Espacio libre para futuras funciones", icon: "ellipsis.circle.fill")
            }

            Spacer()

            HStack(spacing: 12) {
                Button("Volver al mapa") {
                    onClose()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.ctrlPanel)

                Spacer()

                Button("Cerrar sesión") {
                    onLogout()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
    }
}

private struct ManagementCard: View {
    let title: String
    let description: String
    let icon: String
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.ctrlAccent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(description)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ctrlMuted)
                }

                Spacer()

                if action != nil {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.ctrlMuted)
                }
            }
            .padding(20)
            .background(Color.ctrlPanelSoft, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

private struct WorkSiteArchiveView: View {
    @EnvironmentObject private var store: DailyBoardStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Archivo")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            WorkSitePickerCard()

            if let workSite = store.focusedWorkSite {
                VStack(alignment: .leading, spacing: 12) {
                    Text(workSite.name)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("\(workSite.city) · \(workSite.internalCode)")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ctrlMuted)
                }

                if workSiteDocuments.isEmpty {
                    EmptyStateCard(
                        icon: "folder",
                        title: "Archivo listo para usar",
                        description: "Aquí irán los PDF de planos, presupuestos y documentos de esta obra."
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(workSiteDocuments) { document in
                                DocumentRow(document: document, authorName: authorName(for: document.createdByUserId))
                            }
                        }
                    }
                }
            } else {
                EmptyStateCard(
                    icon: "building.2",
                    title: "Selecciona una obra",
                    description: "Elige una obra para ver su archivo."
                )
            }

            HStack {
                Spacer()

                Button("Subir PDF próximamente") {
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.ctrlAccent.opacity(0.5))
                .disabled(true)
            }
        }
    }

    private var workSiteDocuments: [DocumentFile] {
        guard let workSite = store.focusedWorkSite else { return [] }
        return store.documentFiles
            .filter { $0.workSiteId == workSite.id }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func authorName(for userId: String?) -> String {
        guard let userId, let user = store.users.first(where: { $0.id == userId }) else {
            return "Sistema"
        }

        return user.displayName
    }
}

private struct WorkSiteHistoryView: View {
    @EnvironmentObject private var store: DailyBoardStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Historial")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            WorkSitePickerCard()

            if let workSite = store.focusedWorkSite {
                VStack(alignment: .leading, spacing: 12) {
                    Text(workSite.name)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("\(workSite.city) · \(workSite.internalCode)")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ctrlMuted)
                }

                if workSiteEvents.isEmpty {
                    EmptyStateCard(
                        icon: "clock.arrow.circlepath",
                        title: "Sin eventos todavía",
                        description: "Los cambios relevantes de esta obra se registrarán aquí."
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(workSiteEvents) { event in
                                WorkSiteEventRow(event: event, authorName: authorName(for: event.createdByUserId))
                            }
                        }
                    }
                }
            } else {
                EmptyStateCard(
                    icon: "building.2",
                    title: "Selecciona una obra",
                    description: "Elige una obra para ver su historial."
                )
            }
        }
    }

    private var workSiteEvents: [WorkSiteEvent] {
        guard let workSite = store.focusedWorkSite else { return [] }
        return store.workSiteEvents.filter { $0.workSiteId == workSite.id }
    }

    private func authorName(for userId: String?) -> String {
        guard let userId, let user = store.users.first(where: { $0.id == userId }) else {
            return "Sistema"
        }

        return user.displayName
    }
}

private struct WorkSitePickerCard: View {
    @EnvironmentObject private var store: DailyBoardStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Obra")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Picker("Obra", selection: Binding(
                get: { store.focusedWorkSiteId ?? "" },
                set: { store.focusedWorkSiteId = $0.isEmpty ? nil : $0 }
            )) {
                Text("Selecciona una obra").tag("")
                ForEach(store.workSites) { workSite in
                    Text("\(workSite.name) · \(workSite.internalCode)").tag(workSite.id)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)
        }
        .padding(18)
        .background(Color.ctrlPanelSoft, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct EmptyStateCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.ctrlAccent)

            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(description)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ctrlMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(Color.ctrlPanelSoft, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct WorkSiteEventRow: View {
    let event: WorkSiteEvent
    let authorName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(event.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                Text(event.createdAt.ctrlManagementTimestamp)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ctrlMuted)
            }

            Text(event.summary)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ctrlMuted)

            Text(authorName)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ctrlAccent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.ctrlPanelSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct DocumentRow: View {
    let document: DocumentFile
    let authorName: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.richtext.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.ctrlAccent)

            VStack(alignment: .leading, spacing: 4) {
                Text(document.fileName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("\(document.fileType.uppercased()) · \(authorName)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ctrlMuted)
            }

            Spacer()

            Text(document.createdAt.ctrlManagementDate)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ctrlMuted)
        }
        .padding(18)
        .background(Color.ctrlPanelSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private extension Date {
    var ctrlManagementTimestamp: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "dd/MM/yyyy · HH:mm"
        return formatter.string(from: self)
    }

    var ctrlManagementDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: self)
    }
}
