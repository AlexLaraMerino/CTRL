import QuickLook
import PDFKit
import PencilKit
import SwiftUI
import UniformTypeIdentifiers

struct ManagementView: View {
    @EnvironmentObject private var store: DailyBoardStore
    let onClose: () -> Void
    let onLogout: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.ctrlBackground
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
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
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 10)

                    Group {
                        switch store.managementSection {
                        case .home:
                            ManagementHome(onClose: onClose, onLogout: onLogout)
                        case .notebook:
                            NotebookView()
                        case .notes:
                            NotesComposerView()
                        case .board:
                            BoardView()
                        case .archive:
                            WorkSiteArchiveView()
                        case .history:
                            WorkSiteHistoryView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
    }
}

private struct ManagementHome: View {
    @EnvironmentObject private var store: DailyBoardStore
    let onClose: () -> Void
    let onLogout: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gestión")
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Cuaderno operativo, comunicados y archivo de obra.")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ctrlMuted)

                        if let currentUser = store.currentUser {
                            Text("Sesión actual: \(currentUser.displayName)")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.ctrlAccent)
                                .padding(.top, 4)
                        }
                    }

                    Button {
                        store.managementSection = .notebook
                    } label: {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "book.closed.fill")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(Color.ctrlAccent)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(Color.ctrlMuted)
                            }

                            Text("Libreta")
                                .font(.system(size: 32, weight: .black, design: .serif))
                                .foregroundStyle(.white)

                            Text("Abre y escribe. Tus páginas diarias privadas se guardan solas y se recorren como un cuaderno de obra.")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.78))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(24)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.14, green: 0.20, blue: 0.17), Color(red: 0.09, green: 0.13, blue: 0.14)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ManagementCard(title: "Notas", description: "Captura una nota y organízala después", icon: "square.and.pencil") {
                            store.managementSection = .notes
                        }
                        ManagementCard(title: "Tablón", description: "Comunicados internos recibidos", icon: "tray.full.fill") {
                            store.managementSection = .board
                        }
                        ManagementCard(title: "Archivo", description: "PDF, imágenes y documentos por obra", icon: "folder.fill") {
                            store.managementSection = .archive
                        }
                        ManagementCard(title: "Historial", description: "Eventos registrados por obra", icon: "clock.arrow.circlepath") {
                            store.managementSection = .history
                        }
                        ManagementCard(title: "Reservado", description: "Espacio para futuras funciones", icon: "ellipsis.circle.fill")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 4)
                .padding(.bottom, 18)
            }

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
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
    }
}

private struct NotebookView: View {
    @EnvironmentObject private var store: DailyBoardStore
    @State private var selectedNoteId: String?
    @State private var calendarPresented = false
    @State private var sidebarVisible = true
    @State private var noteActionTargetId: String?
    @State private var workSiteConversionNoteId: String?
    @State private var workSiteSearchText = ""

    var body: some View {
        HStack(spacing: 12) {
            if sidebarVisible {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Libreta")
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .foregroundStyle(.white)

                            Text("Páginas del diario en orden cronológico.")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.ctrlMuted)
                        }

                        Spacer()

                        Button {
                            createNewNote()
                        } label: {
                            Image(systemName: "square.and.pencil")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(Color.ctrlPanelSoft, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(store.notebookEntries) { note in
                            NotebookListRow(
                                note: note,
                                isSelected: note.id == selectedNoteId
                            )
                            .onTapGesture {
                                selectedNoteId = note.id
                            }
                            .onLongPressGesture(minimumDuration: 0.45) {
                                noteActionTargetId = note.id
                            }
                            .popover(
                                isPresented: Binding(
                                    get: { noteActionTargetId == note.id },
                                    set: { if !$0, noteActionTargetId == note.id { noteActionTargetId = nil } }
                                ),
                                attachmentAnchor: .rect(.bounds),
                                arrowEdge: .trailing
                            ) {
                                NotebookNoteActionPopover(
                                    onDelete: {
                                        store.deleteNote(note.id)
                                        noteActionTargetId = nil
                                    },
                                    onWorkSiteComment: {
                                        workSiteConversionNoteId = note.id
                                        workSiteSearchText = ""
                                        noteActionTargetId = nil
                                    },
                                    onInternalMessage: {
                                        store.convertDiaryNoteToInternalMessage(noteId: note.id)
                                        noteActionTargetId = nil
                                    }
                                )
                                .presentationCompactAdaptation(.popover)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
                }
                .frame(width: 270, alignment: .topLeading)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            NotebookEditorPage(
                noteId: selectedNoteId,
                onToggleSidebar: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        sidebarVisible.toggle()
                    }
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .animation(.easeInOut(duration: 0.18), value: sidebarVisible)
        .onAppear {
            if selectedNoteId == nil {
                selectedNoteId = store.notebookEntries.last?.id ?? store.createEmptyDiaryNote()
            }
        }
        .onChange(of: store.notebookEntries.map(\.id)) { _, ids in
            if !ids.contains(selectedNoteId ?? ""), let fallback = store.notebookEntries.last?.id {
                selectedNoteId = fallback
            }
        }
        .sheet(isPresented: $calendarPresented) {
            NotebookCalendarSheet(selectedDate: .constant(.now))
        }
        .sheet(isPresented: Binding(
            get: { workSiteConversionNoteId != nil },
            set: { if !$0 { workSiteConversionNoteId = nil } }
        )) {
            WorkSiteSearchSheet(
                searchText: $workSiteSearchText,
                workSites: filteredWorkSites,
                onSelect: { workSite in
                    if let workSiteConversionNoteId {
                        store.convertDiaryNoteToWorkSiteComment(noteId: workSiteConversionNoteId, workSiteId: workSite.id)
                    }
                    selectedNoteId = store.notebookEntries.last?.id
                    noteActionTargetId = nil
                    workSiteConversionNoteId = nil
                    workSiteSearchText = ""
                }
            )
        }
    }

    private func createNewNote() {
        if let noteId = store.createEmptyDiaryNote() {
            selectedNoteId = noteId
        }
    }

    private var filteredWorkSites: [WorkSite] {
        let query = workSiteSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return store.workSites.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }

        return store.workSites.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.city.localizedCaseInsensitiveContains(query) ||
            ($0.addressLine?.localizedCaseInsensitiveContains(query) ?? false) ||
            $0.internalCode.localizedCaseInsensitiveContains(query)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

private struct NotebookNoteActionPopover: View {
    let onDelete: () -> Void
    let onWorkSiteComment: () -> Void
    let onInternalMessage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onWorkSiteComment) {
                Label("Comentario de obra", systemImage: "building.2")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button(action: onInternalMessage) {
                Label("Comunicado interno", systemImage: "person.2")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Divider()

            Button(role: .destructive, action: onDelete) {
                Label("Eliminar nota", systemImage: "trash")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .font(.system(size: 16, weight: .semibold, design: .rounded))
        .foregroundStyle(.white)
        .padding(14)
        .frame(width: 260, alignment: .leading)
        .background(Color.ctrlPanel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct NotesComposerView: View {
    @EnvironmentObject private var store: DailyBoardStore

    var body: some View {
        NoteWorkspaceShell(
            initialNote: store.focusedNoteId.flatMap { store.note(withId: $0) },
            initialType: store.focusedNoteId.flatMap { store.note(withId: $0)?.type } ?? .diary,
            initialDate: store.focusedNoteId.flatMap { store.note(withId: $0)?.createdAt } ?? store.selectedDate,
            readOnly: false
        )
    }
}

private struct BoardView: View {
    @EnvironmentObject private var store: DailyBoardStore
    @State private var selectedNoteId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Tablón")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            if store.boardEntries.isEmpty {
                EmptyStateCard(
                    icon: "tray",
                    title: "Tablón en espera",
                    description: "Cuando alguien te envíe un comunicado interno, aparecerá aquí con su contexto y adjuntos."
                )
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(store.boardEntries) { note in
                            BoardMessageRow(
                                note: note,
                                subtitle: "De \(authorName(for: note.createdByUserId)) · \(note.createdAt.ctrlManagementTimestamp)"
                            )
                            .onTapGesture {
                                selectedNoteId = note.id
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: Binding(
            get: { selectedNote },
            set: { selectedNoteId = $0?.id }
        )) { note in
            NoteWorkspaceSheet(note: note, baseDate: note.createdAt, readOnly: true)
        }
    }

    private func authorName(for userId: String) -> String {
        store.users.first(where: { $0.id == userId })?.displayName ?? userId
    }

    private var selectedNote: NoteEntry? {
        guard let selectedNoteId else { return nil }
        return store.note(withId: selectedNoteId)
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
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.ctrlAccent)

                    Spacer()

                    if action != nil {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Color.ctrlMuted)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(description)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ctrlMuted)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 164, alignment: .topLeading)
            .padding(20)
            .background(Color.ctrlPanelSoft, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

private struct WorkSiteArchiveView: View {
    @EnvironmentObject private var store: DailyBoardStore
    @State private var importerPresented = false
    @State private var previewURL: URL?
    @State private var selectedPDFDocument: DocumentFile?
    @State private var importErrorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Archivo")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            FocusedWorkSitePickerCard()

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
                                DocumentRow(
                                    document: document,
                                    authorName: authorName(for: document.createdByUserId),
                                    onOpen: {
                                        if document.fileType.lowercased() == "pdf" {
                                            selectedPDFDocument = document
                                        } else {
                                            previewURL = store.documentURL(for: document)
                                        }
                                    },
                                    onDelete: {
                                        store.deleteDocument(document.id)
                                    }
                                )
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

                Button("Importar archivo") {
                    importerPresented = true
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.ctrlAccent)
                .disabled(store.focusedWorkSite == nil)
            }
        }
        .fileImporter(
            isPresented: $importerPresented,
            allowedContentTypes: [.pdf, .png, .jpeg, .image],
            allowsMultipleSelection: false
        ) { result in
            guard let workSite = store.focusedWorkSite else { return }

            do {
                let selectedURL = try result.get().first
                guard let selectedURL else { return }
                try store.importDocument(from: selectedURL, into: workSite.id)
            } catch {
                importErrorMessage = "No se ha podido importar el archivo."
            }
        }
        .sheet(isPresented: Binding(
            get: { previewURL != nil },
            set: { if !$0 { previewURL = nil } }
        )) {
            if let previewURL {
                QuickLookPreview(url: previewURL)
            }
        }
        .fullScreenCover(item: $selectedPDFDocument) { document in
            PDFAnnotationEditor(document: document)
        }
        .alert("Importación fallida", isPresented: Binding(
            get: { importErrorMessage != nil },
            set: { if !$0 { importErrorMessage = nil } }
        )) {
            Button("Aceptar", role: .cancel) {
                importErrorMessage = nil
            }
        } message: {
            Text(importErrorMessage ?? "")
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

            FocusedWorkSitePickerCard()

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

private struct FocusedWorkSitePickerCard: View {
    @EnvironmentObject private var store: DailyBoardStore

    var body: some View {
        WorkSitePickerCard(selection: Binding(
            get: { store.focusedWorkSiteId ?? "" },
            set: { store.focusedWorkSiteId = $0.isEmpty ? nil : $0 }
        ))
    }
}

private struct WorkSitePickerCard: View {
    @EnvironmentObject private var store: DailyBoardStore
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Obra")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Picker("Obra", selection: $selection) {
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

private struct RecipientPickerCard: View {
    @EnvironmentObject private var store: DailyBoardStore
    @Binding var selectedRecipientIds: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Destinatarios")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            ForEach(store.activeUsers.filter { $0.id != store.currentUserId }) { user in
                Button {
                    if selectedRecipientIds.contains(user.id) {
                        selectedRecipientIds.remove(user.id)
                    } else {
                        selectedRecipientIds.insert(user.id)
                    }
                } label: {
                    HStack {
                        Text(user.displayName)
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)

                        Spacer()

                        Image(systemName: selectedRecipientIds.contains(user.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedRecipientIds.contains(user.id) ? Color.ctrlAccent : Color.ctrlMuted)
                    }
                    .padding(14)
                    .background(Color.ctrlPanel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
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
    let onOpen: () -> Void
    let onDelete: () -> Void

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

            VStack(alignment: .trailing, spacing: 10) {
                Text(document.createdAt.ctrlManagementDate)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ctrlMuted)

                HStack(spacing: 8) {
                    Button("Abrir") {
                        onOpen()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.ctrlAccent)

                    Button("Borrar") {
                        onDelete()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
        }
        .padding(18)
        .background(Color.ctrlPanelSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct BoardMessageRow: View {
    let note: NoteEntry
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(Color.ctrlAccent.opacity(0.22))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "tray.full.fill")
                        .foregroundStyle(Color.ctrlAccent)
                )

            VStack(alignment: .leading, spacing: 10) {
                Text(note.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ctrlAccent)

                Text(note.body)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ctrlMuted)
                    .lineLimit(5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.ctrlPanelSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct NotebookPage: View {
    let date: Date
    let note: NoteEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text((note?.title ?? date.longSpanishTitle))
                    .font(.system(size: 28, weight: .black, design: .serif))
                    .foregroundStyle(.white)

                Spacer()

                Text(date.ctrlManagementDate)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ctrlMuted)
            }

            if let note {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if let drawingImage = note.noteDrawingPreview {
                            Image(uiImage: drawingImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }

                        Text(note.body.isEmpty ? "Página manuscrita" : note.body)
                            .font(.system(size: 20, weight: .medium, design: .serif))
                            .foregroundStyle(Color.white.opacity(0.92))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Página lista para escribir")
                        .font(.system(size: 26, weight: .black, design: .serif))
                        .foregroundStyle(.white)

                    Text("Toca esta hoja y empieza a escribir con Apple Pencil o teclado. Se guardará automáticamente.")
                        .font(.system(size: 18, weight: .medium, design: .serif))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(26)
        .background(
            LinearGradient(
                colors: [Color(red: 0.16, green: 0.18, blue: 0.15), Color(red: 0.12, green: 0.13, blue: 0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct NotebookEditorPage: View {
    @EnvironmentObject private var store: DailyBoardStore
    let noteId: String?
    let onToggleSidebar: () -> Void

    @State private var editableTitle = ""
    @State private var drawingData: Data?
    @State private var allowsFingerDrawing = false
    @State private var autosaveTask: Task<Void, Never>?

    var body: some View {
        NotebookCanvasSurface(
            title: $editableTitle,
            placeholderTitle: currentNote?.createdAt.longSpanishTitle ?? Date.now.longSpanishTitle,
            drawingData: $drawingData,
            allowsFingerDrawing: $allowsFingerDrawing,
            onToggleSidebar: onToggleSidebar
        )
        .id(noteId ?? "empty-note")
        .onAppear {
            loadCurrentEntry()
        }
        .onChange(of: noteId) { _, _ in
            loadCurrentEntry()
        }
        .onChange(of: editableTitle) { _, _ in scheduleAutosave() }
        .onChange(of: drawingData) { _, _ in scheduleAutosave() }
        .onDisappear {
            autosaveTask?.cancel()
        }
    }

    private func loadCurrentEntry() {
        editableTitle = currentNote?.title ?? ""
        drawingData = currentNote?.drawingData
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            guard let noteId else { return }
            store.updateDiaryPage(
                noteId: noteId,
                title: editableTitle,
                drawingData: drawingData
            )
        }
    }

    private var currentNote: NoteEntry? {
        guard let noteId else { return nil }
        return store.note(withId: noteId)
    }
}

private struct NotebookListRow: View {
    let note: NoteEntry
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(note.title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(note.createdAt.longSpanishTitle)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(isSelected ? Color.white.opacity(0.82) : Color.ctrlMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            isSelected ? Color.ctrlPanel : Color.ctrlPanelSoft,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? Color.ctrlAccent.opacity(0.55) : Color.white.opacity(0.04), lineWidth: 1)
        )
    }
}

private struct WorkSiteSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var searchText: String
    let workSites: [WorkSite]
    let onSelect: (WorkSite) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TextField("Buscar obra", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.ctrlPanelSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(workSites) { workSite in
                            Button {
                                onSelect(workSite)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(workSite.name)
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)

                                    Text("\(workSite.city) · \(workSite.internalCode)")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color.ctrlMuted)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(Color.ctrlPanelSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
            .padding(16)
            .background(Color.ctrlBackground.ignoresSafeArea())
            .navigationTitle("Comentario de obra")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct NotebookCanvasSurface: View {
    @Binding var title: String
    let placeholderTitle: String
    @Binding var drawingData: Data?
    @Binding var allowsFingerDrawing: Bool
    let onToggleSidebar: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NotebookInfiniteCanvasRepresentable(
                drawingData: $drawingData,
                allowsFingerDrawing: allowsFingerDrawing,
                onToggleSidebar: onToggleSidebar
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(alignment: .center, spacing: 12) {
                TextField(placeholderTitle, text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 28, weight: .black, design: .serif))
                    .foregroundStyle(Color(red: 0.15, green: 0.16, blue: 0.14))
                    .lineLimit(2)

                Spacer(minLength: 12)

                Toggle(isOn: $allowsFingerDrawing) {
                    Text("Dedo")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.18, green: 0.18, blue: 0.17))
                }
                .toggleStyle(.switch)
                .labelsHidden()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.top, 12)
            .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.94, blue: 0.89), Color(red: 0.91, green: 0.89, blue: 0.84)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
    }
}

private struct NotebookCalendarSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                DatePicker(
                    "Fecha",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .tint(Color.ctrlAccent)
                .padding()

                Spacer()
            }
            .background(Color.ctrlBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
            .navigationTitle("Ir a fecha")
        }
    }
}

private struct NoteWorkspaceSheet: View {
    let note: NoteEntry
    let baseDate: Date
    let readOnly: Bool

    var body: some View {
        NoteWorkspaceShell(
            initialNote: note.id.hasPrefix("draft-") ? nil : note,
            initialType: note.type,
            initialDate: baseDate,
            readOnly: readOnly
        )
    }
}

private struct NoteWorkspaceShell: View {
    @EnvironmentObject private var store: DailyBoardStore
    @Environment(\.dismiss) private var dismiss

    let initialNote: NoteEntry?
    let initialType: NoteEntryType
    let initialDate: Date
    let readOnly: Bool

    @State private var noteId: String?
    @State private var type: NoteEntryType
    @State private var title: String
    @State private var noteBody: String
    @State private var drawingData: Data?
    @State private var selectedWorkSiteId: String
    @State private var selectedRecipientIds: Set<String>
    @State private var allowsFingerDrawing = false
    @State private var autosaveTask: Task<Void, Never>?

    init(initialNote: NoteEntry?, initialType: NoteEntryType, initialDate: Date, readOnly: Bool) {
        self.initialNote = initialNote
        self.initialType = initialNote?.type ?? initialType
        self.initialDate = initialDate
        self.readOnly = readOnly
        _noteId = State(initialValue: initialNote?.id)
        _type = State(initialValue: initialNote?.type ?? initialType)
        _title = State(initialValue: initialNote?.title ?? initialDate.longSpanishTitle)
        _noteBody = State(initialValue: initialNote?.body ?? "")
        _drawingData = State(initialValue: initialNote?.drawingData)
        _selectedWorkSiteId = State(initialValue: initialNote?.workSiteId ?? "")
        _selectedRecipientIds = State(initialValue: Set(initialNote?.recipientUserIds ?? []))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ctrlBackground
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    workspaceHeader
                    workspaceContextStrip
                    NotePageSurface(
                        title: effectiveTitle,
                        bodyText: $noteBody,
                        drawingData: $drawingData,
                        readOnly: readOnly,
                        allowsFingerDrawing: $allowsFingerDrawing
                    )
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }

                if !readOnly {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Borrar", role: .destructive) {
                            if let noteId {
                                store.deleteNote(noteId)
                            }
                            dismiss()
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: type) { _, _ in scheduleAutosave() }
            .onChange(of: title) { _, _ in scheduleAutosave() }
            .onChange(of: noteBody) { _, _ in scheduleAutosave() }
            .onChange(of: drawingData) { _, _ in scheduleAutosave() }
            .onChange(of: selectedWorkSiteId) { _, _ in scheduleAutosave() }
            .onChange(of: selectedRecipientIds) { _, _ in scheduleAutosave() }
            .onDisappear {
                autosaveTask?.cancel()
            }
        }
    }

    private var workspaceHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(type == .diary ? "Libreta" : "Nota")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(type == .diary ? initialDate.longSpanishTitle : type.title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ctrlMuted)
            }

            Spacer()

            if !readOnly {
                Toggle(isOn: $allowsFingerDrawing) {
                    Text("Dedo")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .toggleStyle(.switch)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.ctrlPanelSoft, in: Capsule())
            }
        }
    }

    private var workspaceContextStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ContextChip(label: type.title, icon: "square.and.pencil") {
                    if !readOnly {
                        cycleType()
                    }
                }

                if type == .workSiteComment {
                    ContextMenuChip(
                        title: selectedWorkSiteTitle,
                        icon: "building.2.fill",
                        options: store.workSites.map { ($0.id, $0.name) },
                        selection: $selectedWorkSiteId,
                        disabled: readOnly
                    )
                }

                if type == .internalMessage {
                    MultiRecipientChip(
                        selectedRecipientIds: $selectedRecipientIds,
                        disabled: readOnly
                    )
                }

                if type == .diary {
                    ContextChip(label: "Privada", icon: "person.fill") { }
                }
            }
        }
    }

    private var effectiveTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? initialDate.longSpanishTitle : trimmed
    }

    private var selectedWorkSiteTitle: String {
        store.workSites.first(where: { $0.id == selectedWorkSiteId })?.name ?? "Elegir obra"
    }

    private func cycleType() {
        let ordered = NoteEntryType.allCases
        guard let index = ordered.firstIndex(of: type) else { return }
        type = ordered[(index + 1) % ordered.count]
    }

    private func scheduleAutosave() {
        guard !readOnly else { return }

        autosaveTask?.cancel()
        autosaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            noteId = store.upsertNoteDraft(
                noteId: noteId,
                type: type,
                title: effectiveTitle,
                body: noteBody,
                drawingData: drawingData,
                workSiteId: type == .workSiteComment ? selectedWorkSiteId.nonEmpty : nil,
                recipientUserIds: type == .internalMessage ? Array(selectedRecipientIds) : []
            )
        }
    }
}

private struct NotePageSurface: View {
    let title: String
    @Binding var bodyText: String
    @Binding var drawingData: Data?
    let readOnly: Bool
    @Binding var allowsFingerDrawing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.system(size: 30, weight: .black, design: .serif))
                .foregroundStyle(Color(red: 0.15, green: 0.16, blue: 0.14))

            TextEditor(text: $bodyText)
                .scrollContentBackground(.hidden)
                .font(.system(size: 21, weight: .medium, design: .serif))
                .foregroundStyle(Color(red: 0.18, green: 0.18, blue: 0.17))
                .frame(minHeight: 220)
                .disabled(readOnly)

            Divider()
                .overlay(Color.black.opacity(0.12))

            if readOnly, let drawingImage = drawingPreview {
                Image(uiImage: drawingImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                PencilNoteCanvasRepresentable(
                    drawingData: $drawingData,
                    isReadOnly: readOnly,
                    allowsFingerDrawing: allowsFingerDrawing
                )
                .frame(minHeight: 340)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.94, blue: 0.89), Color(red: 0.91, green: 0.89, blue: 0.84)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
    }

    private var drawingPreview: UIImage? {
        guard let drawingData,
              let drawing = try? PKDrawing(data: drawingData) else {
            return nil
        }

        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 720)
        return drawing.image(from: bounds, scale: 1)
    }
}

private struct ContextChip: View {
    let label: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.ctrlPanelSoft, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct ContextMenuChip: View {
    let title: String
    let icon: String
    let options: [(String, String)]
    @Binding var selection: String
    var disabled = false

    var body: some View {
        Menu {
            ForEach(options, id: \.0) { option in
                Button(option.1) {
                    selection = option.0
                }
            }
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.ctrlPanelSoft, in: Capsule())
        }
        .disabled(disabled)
    }
}

private struct MultiRecipientChip: View {
    @EnvironmentObject private var store: DailyBoardStore
    @Binding var selectedRecipientIds: Set<String>
    var disabled = false

    var body: some View {
        Menu {
            ForEach(store.activeUsers.filter { $0.id != store.currentUserId }) { user in
                Button {
                    if selectedRecipientIds.contains(user.id) {
                        selectedRecipientIds.remove(user.id)
                    } else {
                        selectedRecipientIds.insert(user.id)
                    }
                } label: {
                    Label(
                        user.displayName,
                        systemImage: selectedRecipientIds.contains(user.id) ? "checkmark.circle.fill" : "circle"
                    )
                }
            }
        } label: {
            Label(recipientLabel, systemImage: "person.2.fill")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.ctrlPanelSoft, in: Capsule())
        }
        .disabled(disabled)
    }

    private var recipientLabel: String {
        selectedRecipientIds.isEmpty ? "Destinatarios" : "\(selectedRecipientIds.count) destinatarios"
    }
}

private struct PencilNoteCanvasRepresentable: UIViewRepresentable {
    @Binding var drawingData: Data?
    let isReadOnly: Bool
    let allowsFingerDrawing: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(drawingData: $drawingData)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = UIColor.clear
        canvas.isOpaque = false
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = allowsFingerDrawing ? .anyInput : .pencilOnly
        canvas.isUserInteractionEnabled = !isReadOnly

        if let drawingData,
           let drawing = try? PKDrawing(data: drawingData) {
            canvas.drawing = drawing
        }

        let toolPicker = PKToolPicker()
        toolPicker.setVisible(!isReadOnly, forFirstResponder: canvas)
        toolPicker.addObserver(canvas)
        context.coordinator.toolPicker = toolPicker
        canvas.becomeFirstResponder()
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.drawingPolicy = allowsFingerDrawing ? .anyInput : .pencilOnly
        uiView.isUserInteractionEnabled = !isReadOnly
        if let drawingData,
           let drawing = try? PKDrawing(data: drawingData),
           uiView.drawing != drawing {
            uiView.drawing = drawing
        }
    }

    static func dismantleUIView(_ uiView: PKCanvasView, coordinator: Coordinator) {
        coordinator.toolPicker?.setVisible(false, forFirstResponder: uiView)
        if let toolPicker = coordinator.toolPicker {
            toolPicker.removeObserver(uiView)
        }
        uiView.resignFirstResponder()
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var drawingData: Data?
        var toolPicker: PKToolPicker?

        init(drawingData: Binding<Data?>) {
            _drawingData = drawingData
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawingData = canvasView.drawing.dataRepresentation()
        }
    }
}

private struct NotebookInfiniteCanvasRepresentable: UIViewRepresentable {
    @Binding var drawingData: Data?
    let allowsFingerDrawing: Bool
    let onToggleSidebar: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(drawingData: $drawingData, onToggleSidebar: onToggleSidebar)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = UIColor(red: 0.95, green: 0.93, blue: 0.88, alpha: 1)
        canvas.isOpaque = true
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = allowsFingerDrawing ? .anyInput : .pencilOnly
        canvas.alwaysBounceVertical = true
        canvas.alwaysBounceHorizontal = true
        canvas.bouncesZoom = true
        canvas.minimumZoomScale = 0.35
        canvas.maximumZoomScale = 4.0
        canvas.zoomScale = 1.0
        canvas.contentSize = CGSize(width: 5200, height: 5200)
        canvas.contentInset = UIEdgeInsets(top: 600, left: 600, bottom: 600, right: 600)
        canvas.showsVerticalScrollIndicator = false
        canvas.showsHorizontalScrollIndicator = false
        canvas.contentOffset = CGPoint(x: 1800, y: 200)

        if let drawingData,
           let drawing = try? PKDrawing(data: drawingData) {
            canvas.drawing = drawing
        }

        let toolPicker = PKToolPicker()
        toolPicker.setVisible(true, forFirstResponder: canvas)
        toolPicker.addObserver(canvas)
        context.coordinator.toolPicker = toolPicker

        let toggleGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTwoFingerDoubleTap))
        toggleGesture.numberOfTouchesRequired = 2
        toggleGesture.numberOfTapsRequired = 2
        toggleGesture.cancelsTouchesInView = false
        canvas.addGestureRecognizer(toggleGesture)

        canvas.becomeFirstResponder()
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.drawingPolicy = allowsFingerDrawing ? .anyInput : .pencilOnly
        if let drawingData,
           let drawing = try? PKDrawing(data: drawingData),
           uiView.drawing != drawing {
            uiView.drawing = drawing
        }
    }

    static func dismantleUIView(_ uiView: PKCanvasView, coordinator: Coordinator) {
        coordinator.toolPicker?.setVisible(false, forFirstResponder: uiView)
        if let toolPicker = coordinator.toolPicker {
            toolPicker.removeObserver(uiView)
        }
        uiView.resignFirstResponder()
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var drawingData: Data?
        var toolPicker: PKToolPicker?
        let onToggleSidebar: () -> Void

        init(drawingData: Binding<Data?>, onToggleSidebar: @escaping () -> Void) {
            _drawingData = drawingData
            self.onToggleSidebar = onToggleSidebar
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawingData = canvasView.drawing.dataRepresentation()
        }

        @objc func handleTwoFingerDoubleTap() {
            onToggleSidebar()
        }
    }
}

private struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        context.coordinator.url = url
        uiViewController.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}

private struct PDFAnnotationEditor: View {
    @EnvironmentObject private var store: DailyBoardStore
    @Environment(\.dismiss) private var dismiss
    let document: DocumentFile
    @StateObject private var session = PDFEditorSession()
    @State private var saveErrorMessage: String?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.ctrlBackground
                .ignoresSafeArea()

            if let documentURL = store.documentURL(for: document) {
                PDFEditorRepresentable(
                    url: documentURL,
                    session: session
                )
                .ignoresSafeArea()
            } else {
                EmptyStateCard(
                    icon: "doc",
                    title: "No se puede abrir el PDF",
                    description: "El archivo no está disponible en este momento."
                )
                .padding(24)
            }

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Toggle(isOn: $session.allowsFingerDrawing) {
                        Text("Dedo")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .toggleStyle(.switch)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())

                    Spacer()

                    EditorActionButton(title: "Cerrar", tint: Color.ctrlPanel) {
                        dismiss()
                    }

                    EditorActionButton(title: "Guardar", tint: Color.ctrlAccent) {
                        do {
                            try store.overwritePDFDocument(document.id, drawingsByPage: session.drawingsByPage)
                            dismiss()
                        } catch {
                            saveErrorMessage = "No se ha podido sobrescribir el PDF."
                        }
                    }

                    EditorActionButton(title: "Guardar copia", tint: Color.orange) {
                        do {
                            try store.saveAnnotatedPDFCopy(document.id, drawingsByPage: session.drawingsByPage)
                            dismiss()
                        } catch {
                            saveErrorMessage = "No se ha podido guardar la copia anotada."
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)

                Spacer()
            }
        }
        .alert("Guardado fallido", isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            Button("Aceptar", role: .cancel) {
                saveErrorMessage = nil
            }
        } message: {
            Text(saveErrorMessage ?? "")
        }
    }
}

private final class PDFEditorSession: ObservableObject {
    @Published var allowsFingerDrawing = false
    @Published var drawingsByPage: [Int: Data] = [:]
}

private struct PDFEditorRepresentable: UIViewControllerRepresentable {
    let url: URL
    @ObservedObject var session: PDFEditorSession

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    func makeUIViewController(context: Context) -> PDFEditorViewController {
        let controller = PDFEditorViewController()
        controller.configure(
            url: url,
            coordinator: context.coordinator,
            allowsFingerDrawing: session.allowsFingerDrawing
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: PDFEditorViewController, context: Context) {
        uiViewController.setAllowsFingerDrawing(session.allowsFingerDrawing)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let session: PDFEditorSession
        weak var controller: PDFEditorViewController?
        var currentPageIndex = 0

        init(session: PDFEditorSession) {
            self.session = session
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            session.drawingsByPage[currentPageIndex] = canvasView.drawing.dataRepresentation()
        }

        func loadDrawing(for pageIndex: Int, into canvasView: PKCanvasView) {
            currentPageIndex = pageIndex
            if let data = session.drawingsByPage[pageIndex],
               let drawing = try? PKDrawing(data: data) {
                canvasView.drawing = drawing
            } else {
                canvasView.drawing = PKDrawing()
            }
        }
    }
}

private final class PDFEditorViewController: UIViewController, PDFViewDelegate {
    private let pdfView = PDFView()
    private let canvasView = PencilPassthroughCanvasView()
    private var pageObserver: NSObjectProtocol?
    private var toolPicker: PKToolPicker?
    private weak var editorCoordinator: PDFEditorRepresentable.Coordinator?

    deinit {
        if let pageObserver {
            NotificationCenter.default.removeObserver(pageObserver)
        }
    }

    func configure(url: URL, coordinator: PDFEditorRepresentable.Coordinator, allowsFingerDrawing: Bool) {
        self.editorCoordinator = coordinator
        coordinator.controller = self

        let pdfDocument = PDFDocument(url: url)

        pdfView.document = pdfDocument
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        pdfView.usePageViewController(true, withViewOptions: nil)
        pdfView.delegate = self

        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = allowsFingerDrawing ? .anyInput : .pencilOnly
        canvasView.allowsFingerInput = allowsFingerDrawing
        canvasView.delegate = coordinator

        pageObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name.PDFViewPageChanged,
            object: pdfView,
            queue: .main
        ) { [weak self] _ in
            self?.syncCurrentPage()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(Color.ctrlBackground)

        pdfView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(pdfView)
        view.addSubview(canvasView)

        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            pdfView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pdfView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            canvasView.topAnchor.constraint(equalTo: pdfView.topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: pdfView.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: pdfView.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: pdfView.bottomAnchor)
        ])

        let toolPicker = PKToolPicker()
        self.toolPicker = toolPicker
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)

        canvasView.becomeFirstResponder()
        syncCurrentPage()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        canvasView.becomeFirstResponder()
    }

    private func syncCurrentPage() {
        guard let pdfDocument = pdfView.document,
              let currentPage = pdfView.currentPage,
              let pageIndex = pdfDocument.index(for: currentPage) as Int?,
              let editorCoordinator else {
            return
        }

        editorCoordinator.loadDrawing(for: pageIndex, into: canvasView)
    }

    func setAllowsFingerDrawing(_ allowsFingerDrawing: Bool) {
        canvasView.drawingPolicy = allowsFingerDrawing ? .anyInput : .pencilOnly
        canvasView.allowsFingerInput = allowsFingerDrawing
    }
}

private final class PencilPassthroughCanvasView: PKCanvasView {
    var allowsFingerInput = false

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !allowsFingerInput else {
            return super.hitTest(point, with: event)
        }

        if let touches = event?.allTouches, touches.contains(where: { $0.type == .pencil }) {
            return super.hitTest(point, with: event)
        }

        return nil
    }
}

private struct EditorActionButton: View {
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(tint, in: Capsule())
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

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension NoteEntry {
    var noteDrawingPreview: UIImage? {
        guard let drawingData,
              let drawing = try? PKDrawing(data: drawingData) else {
            return nil
        }

        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 720)
        return drawing.image(from: bounds, scale: 1)
    }
}
