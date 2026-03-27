import CoreLocation
import Foundation
import PDFKit
import PencilKit
import UIKit

@MainActor
final class DailyBoardStore: ObservableObject {
    @Published var selectedDate: Date
    @Published var users: [User]
    @Published var employees: [Employee]
    @Published var workSites: [WorkSite]
    @Published var dailyStates: [String: DailyState]
    @Published var noteEntries: [NoteEntry]
    @Published var documentAnnotations: [DocumentAnnotation]
    @Published var documentFiles: [DocumentFile]
    @Published var workSiteEvents: [WorkSiteEvent]
    @Published var leftPanelVisible = false
    @Published var rightPanel: RightPanel = .none
    @Published var relocation = RelocationState(employeeId: nil)
    @Published var calendarMonth: Date
    @Published var spainTimeText: String
    @Published var copiedDayState: DailyState?
    @Published var currentUserId: String?
    @Published var managementVisible = false
    @Published var managementSection: ManagementSection = .home
    @Published var focusedWorkSiteId: String?
    @Published var focusedNoteId: String?
    @Published var managementRequestID = UUID()

    private let persistence = DailyBoardPersistence()
    private let authPersistence = AuthSessionPersistence()
    private var timer: Timer?

    init() {
        let initialSelectedDate: Date
        let initialUsers: [User]
        let initialEmployees: [Employee]
        let initialWorkSites: [WorkSite]
        let initialDailyStates: [String: DailyState]
        let initialNoteEntries: [NoteEntry]
        let initialDocumentAnnotations: [DocumentAnnotation]
        let initialDocumentFiles: [DocumentFile]
        let initialWorkSiteEvents: [WorkSiteEvent]

        if let snapshot = persistence.load() {
            initialSelectedDate = Date(ctrlKey: snapshot.selectedDate) ?? .now
            initialUsers = snapshot.users
            initialEmployees = snapshot.employees
            initialWorkSites = snapshot.workSites
            initialDailyStates = snapshot.dailyStates
            initialNoteEntries = persistence.loadNoteDocuments(fallback: snapshot.noteEntries)
            initialDocumentAnnotations = snapshot.documentAnnotations
            initialDocumentFiles = snapshot.documentFiles
            initialWorkSiteEvents = snapshot.workSiteEvents
        } else {
            let today = Calendar.ctrl.startOfDay(for: .now)
            let users = MockData.users
            let employees = MockData.employees
            let workSites = MockData.workSites
            initialSelectedDate = today
            initialUsers = users
            initialEmployees = employees
            initialWorkSites = workSites
            initialDailyStates = [today.ctrlKey: MockData.seedDailyState(for: today, employees: employees, workSites: workSites)]
            initialNoteEntries = persistence.loadNoteDocuments(fallback: [])
            initialDocumentAnnotations = []
            initialDocumentFiles = []
            initialWorkSiteEvents = []
        }

        self.selectedDate = initialSelectedDate
        self.users = initialUsers
        self.employees = initialEmployees
        self.workSites = initialWorkSites
        self.dailyStates = initialDailyStates
        self.noteEntries = initialNoteEntries
        self.documentAnnotations = initialDocumentAnnotations
        self.documentFiles = initialDocumentFiles
        self.workSiteEvents = initialWorkSiteEvents
        self.calendarMonth = Calendar.ctrl.startOfMonth(for: initialSelectedDate)
        self.spainTimeText = Self.currentSpainTimeText()
        self.currentUserId = authPersistence.loadRememberedUserId()
        ensureDay(selectedDate)
        startClock()
    }

    deinit {
        timer?.invalidate()
    }

    var dailyState: DailyState {
        ensureDay(selectedDate)
        return dailyStates[selectedDate.ctrlKey] ?? MockData.seedDailyState(for: selectedDate, employees: employees, workSites: workSites)
    }

    var activeEmployees: [Employee] {
        employees.filter(\.isActive)
    }

    var activeUsers: [User] {
        users.filter(\.isActive)
    }

    var currentUser: User? {
        guard let currentUserId else { return nil }
        return users.first(where: { $0.id == currentUserId })
    }

    var inactiveEmployees: [Employee] {
        employees.filter { !$0.isActive }
    }

    var activeWorkSites: [WorkSite] {
        workSites.filter(\.isActive)
    }

    var inactiveWorkSites: [WorkSite] {
        workSites.filter { !$0.isActive }
    }

    var focusedWorkSite: WorkSite? {
        guard let focusedWorkSiteId else { return nil }
        return workSites.first(where: { $0.id == focusedWorkSiteId })
    }

    var notebookEntries: [NoteEntry] {
        guard let currentUserId else { return [] }
        return noteEntries
            .filter { $0.type == .diary && $0.createdByUserId == currentUserId }
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                }
                return lhs.createdAt < rhs.createdAt
            }
    }

    func diaryEntry(on date: Date) -> NoteEntry? {
        guard let currentUserId else { return nil }
        return noteEntries.first {
            $0.type == .diary
                && $0.createdByUserId == currentUserId
                && Calendar.ctrl.isDate($0.createdAt, inSameDayAs: date)
        }
    }

    var boardEntries: [NoteEntry] {
        guard let currentUserId else { return [] }
        return noteEntries
            .filter { $0.type == .internalMessage && $0.recipientUserIds.contains(currentUserId) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func note(withId noteId: String) -> NoteEntry? {
        noteEntries.first(where: { $0.id == noteId })
    }

    func login(pin4: String, rememberUser: Bool) -> Bool {
        guard let user = activeUsers.first(where: { $0.pin4 == pin4 }) else {
            return false
        }

        currentUserId = user.id
        if rememberUser {
            authPersistence.saveRememberedUserId(user.id)
        } else {
            authPersistence.clearRememberedUserId()
        }
        return true
    }

    func logout() {
        managementVisible = false
        managementSection = .home
        focusedWorkSiteId = nil
        currentUserId = nil
        authPersistence.clearRememberedUserId()
    }

    func selectDate(_ date: Date) {
        selectedDate = Calendar.ctrl.startOfDay(for: date)
        calendarMonth = Calendar.ctrl.startOfMonth(for: selectedDate)
        ensureDay(selectedDate)
    }

    func shiftCalendarMonth(by months: Int) {
        calendarMonth = Calendar.ctrl.date(byAdding: .month, value: months, to: calendarMonth) ?? calendarMonth
    }

    func shiftSelectedDate(by days: Int) {
        selectDate(selectedDate.adding(days: days))
    }

    func goToToday() {
        selectDate(.now)
    }

    func updateNotes(_ notes: String) {
        mutateDailyState(for: selectedDate) {
            $0.notes = notes
        }
    }

    func toggleWorkSiteVisibility(_ workSiteId: String) {
        guard workSites.contains(where: { $0.id == workSiteId && $0.isActive }) else { return }

        mutateDailyState(for: selectedDate) { state in
            if state.visibleWorkSiteIds.contains(workSiteId) {
                state.visibleWorkSiteIds.removeAll { $0 == workSiteId }
            } else {
                state.visibleWorkSiteIds.append(workSiteId)
            }
        }
    }

    func moveEmployee(_ employeeId: String, to latitude: Double, longitude: Double, workSiteId: String? = nil) {
        mutateDailyState(for: selectedDate) { state in
            state.employeePlacements[employeeId] = EmployeePlacement(
                employeeId: employeeId,
                lat: latitude,
                lng: longitude,
                workSiteId: workSiteId
            )
        }
    }

    func placeEmployee(_ employeeId: String, at coordinate: CLLocationCoordinate2D) {
        if let snappedWorkSite = nearestVisibleWorkSite(to: coordinate) {
            moveEmployee(
                employeeId,
                to: snappedWorkSite.lat,
                longitude: snappedWorkSite.lng,
                workSiteId: snappedWorkSite.id
            )
            return
        }

        moveEmployee(
            employeeId,
            to: coordinate.latitude,
            longitude: coordinate.longitude,
            workSiteId: nil
        )
    }

    func isEmployeeAbsent(_ employeeId: String) -> Bool {
        dailyState.absentEmployeeIds.contains(employeeId)
    }

    func addEmployee(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else { return }

        let employee = Employee(
            id: "emp-\(UUID().uuidString.lowercased())",
            name: trimmed,
            colorHex: Self.palette[employees.count % Self.palette.count],
            isActive: true
        )

        employees.append(employee)
        mutateDailyState(for: selectedDate) { state in
            state.employeePlacements[employee.id] = EmployeePlacement(
                employeeId: employee.id,
                lat: 40.4168,
                lng: -3.7038,
                workSiteId: nil
            )
        }
        persist()
    }

    func updateEmployeeName(_ employeeId: String, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard let index = employees.firstIndex(where: { $0.id == employeeId }) else { return }
        employees[index].name = trimmed
        persist()
    }

    func setEmployeeActive(_ employeeId: String, isActive: Bool) {
        guard let index = employees.firstIndex(where: { $0.id == employeeId }) else { return }
        employees[index].isActive = isActive
        persist()
    }

    func toggleEmployeeAbsence(_ employeeId: String) {
        mutateDailyState(for: selectedDate) { state in
            if state.absentEmployeeIds.contains(employeeId) {
                state.absentEmployeeIds.removeAll { $0 == employeeId }
            } else {
                state.absentEmployeeIds.append(employeeId)
            }
        }
    }

    func prepareRelocation(for employeeId: String) {
        relocation.employeeId = employeeId
    }

    func addWorkSite(name: String, city: String, addressLine: String = "") async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = addressLine.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty, !trimmedCity.isEmpty else { return }

        let coordinate = await coordinateForLocation(city: trimmedCity, addressLine: trimmedAddress.isEmpty ? nil : trimmedAddress)
        let workSite = WorkSite(
            id: "ws-\(UUID().uuidString.lowercased())",
            internalCode: makeUniqueWorkSiteCode(),
            name: trimmedName,
            city: trimmedCity,
            addressLine: trimmedAddress.isEmpty ? nil : trimmedAddress,
            lat: coordinate.latitude,
            lng: coordinate.longitude,
            isActive: true
        )

        workSites.append(workSite)
        mutateDailyState(for: selectedDate) { state in
            if !state.visibleWorkSiteIds.contains(workSite.id) {
                state.visibleWorkSiteIds.append(workSite.id)
            }
        }
        appendWorkSiteEvent(
            workSiteId: workSite.id,
            type: "created",
            title: "Obra creada",
            summary: "Se ha creado la obra \(workSite.name) en \(workSite.city)."
        )
        persist()
    }

    func updateWorkSite(_ workSiteId: String, name: String, city: String, addressLine: String = "") async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = addressLine.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty, !trimmedCity.isEmpty else { return }
        guard let index = workSites.firstIndex(where: { $0.id == workSiteId }) else { return }

        let coordinate = await coordinateForLocation(city: trimmedCity, addressLine: trimmedAddress.isEmpty ? nil : trimmedAddress)
        workSites[index].name = trimmedName
        workSites[index].city = trimmedCity
        workSites[index].addressLine = trimmedAddress.isEmpty ? nil : trimmedAddress
        workSites[index].lat = coordinate.latitude
        workSites[index].lng = coordinate.longitude
        appendWorkSiteEvent(
            workSiteId: workSiteId,
            type: "updated",
            title: "Obra modificada",
            summary: "Se ha actualizado la obra \(trimmedName) en \(trimmedCity)."
        )
        persist()
    }

    func setWorkSiteActive(_ workSiteId: String, isActive: Bool) {
        guard let index = workSites.firstIndex(where: { $0.id == workSiteId }) else { return }
        workSites[index].isActive = isActive

        if isActive {
            mutateDailyState(for: selectedDate) { state in
                if !state.visibleWorkSiteIds.contains(workSiteId) {
                    state.visibleWorkSiteIds.append(workSiteId)
                }
            }
            appendWorkSiteEvent(
                workSiteId: workSiteId,
                type: "activated",
                title: "Obra activada",
                summary: "La obra vuelve a estar disponible en la operativa diaria."
            )
        } else {
            mutateDailyState(for: selectedDate) { state in
                state.visibleWorkSiteIds.removeAll { $0 == workSiteId }
            }
            appendWorkSiteEvent(
                workSiteId: workSiteId,
                type: "deactivated",
                title: "Obra desactivada",
                summary: "La obra se ha movido a la lista de inactivas."
            )
        }

        persist()
    }

    func openManagementHome() {
        managementSection = .home
        focusedWorkSiteId = nil
        focusedNoteId = nil
        managementRequestID = UUID()
    }

    func openManagement(section: ManagementSection, workSiteId: String? = nil) {
        managementSection = section
        focusedWorkSiteId = workSiteId
        managementRequestID = UUID()
    }

    func closeManagementContext() {
        managementSection = .home
        focusedWorkSiteId = nil
        focusedNoteId = nil
    }

    func createNote(
        type: NoteEntryType,
        title: String,
        body: String,
        drawingData: Data?,
        workSiteId: String?,
        recipientUserIds: [String]
    ) {
        guard let currentUserId else { return }

        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty || drawingData != nil else { return }

        let normalizedTitle = normalizedNoteTitle(type: type, title: title)
        let note = NoteEntry(
            id: "note-\(UUID().uuidString.lowercased())",
            type: type,
            title: normalizedTitle,
            body: trimmedBody,
            drawingData: drawingData,
            createdAt: .now,
            updatedAt: .now,
            createdByUserId: currentUserId,
            workSiteId: type == .workSiteComment ? workSiteId : nil,
            recipientUserIds: type == .internalMessage ? recipientUserIds : []
        )

        noteEntries.insert(note, at: 0)

        if type == .workSiteComment, let workSiteId, let workSite = workSites.first(where: { $0.id == workSiteId }) {
            appendWorkSiteEvent(
                workSiteId: workSiteId,
                type: "worksite_note",
                title: "Nota de obra",
                summary: "Se ha añadido una nota a \(workSite.name): \(trimmedBody.prefix(80))"
            )
        }

        persist()
    }

    func updateNote(
        noteId: String,
        type: NoteEntryType,
        title: String,
        body: String,
        drawingData: Data?,
        workSiteId: String?,
        recipientUserIds: [String]
    ) {
        guard let index = noteEntries.firstIndex(where: { $0.id == noteId }) else { return }

        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty || drawingData != nil else { return }

        let previousType = noteEntries[index].type
        let previousWorkSiteId = noteEntries[index].workSiteId
        noteEntries[index].type = type
        noteEntries[index].title = normalizedNoteTitle(type: type, title: title)
        noteEntries[index].body = trimmedBody
        noteEntries[index].drawingData = drawingData
        noteEntries[index].updatedAt = .now
        noteEntries[index].workSiteId = type == .workSiteComment ? workSiteId : nil
        noteEntries[index].recipientUserIds = type == .internalMessage ? recipientUserIds : []

        if previousType == .workSiteComment,
           previousWorkSiteId != workSiteId,
           let previousWorkSiteId {
            appendWorkSiteEvent(
                workSiteId: previousWorkSiteId,
                type: "worksite_note_moved",
                title: "Nota de obra reasignada",
                summary: "Una nota ha cambiado de contexto de obra."
            )
        }

        if type == .workSiteComment, let workSiteId, let workSite = workSites.first(where: { $0.id == workSiteId }) {
            appendWorkSiteEvent(
                workSiteId: workSiteId,
                type: "worksite_note_updated",
                title: "Nota de obra actualizada",
                summary: "Se ha actualizado una nota en \(workSite.name): \(trimmedBody.prefix(80))"
            )
        }

        persist()
    }

    func upsertNoteDraft(
        noteId: String?,
        type: NoteEntryType,
        title: String,
        body: String,
        drawingData: Data?,
        workSiteId: String?,
        recipientUserIds: [String]
    ) -> String? {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty || drawingData != nil else { return noteId }

        if let noteId, noteEntries.contains(where: { $0.id == noteId }) {
            updateNote(
                noteId: noteId,
                type: type,
                title: title,
                body: trimmedBody,
                drawingData: drawingData,
                workSiteId: workSiteId,
                recipientUserIds: recipientUserIds
            )
            return noteId
        }

        createNote(
            type: type,
            title: title,
            body: trimmedBody,
            drawingData: drawingData,
            workSiteId: workSiteId,
            recipientUserIds: recipientUserIds
        )

        return noteEntries.first?.id
    }

    @discardableResult
    func createEmptyDiaryNote(on date: Date = .now) -> String? {
        guard let currentUserId else { return nil }

        let creationDate = date
        let note = NoteEntry(
            id: "note-\(UUID().uuidString.lowercased())",
            type: .diary,
            title: nextDiaryTitle(for: creationDate),
            body: "",
            drawingData: nil,
            createdAt: creationDate,
            updatedAt: creationDate,
            createdByUserId: currentUserId,
            workSiteId: nil,
            recipientUserIds: []
        )

        noteEntries.append(note)
        persist()
        return note.id
    }

    func updateDiaryPage(noteId: String, title: String, drawingData: Data?) {
        guard let index = noteEntries.firstIndex(where: { $0.id == noteId && $0.type == .diary }) else { return }

        noteEntries[index].title = normalizedNoteTitle(type: .diary, title: title, fallbackDate: noteEntries[index].createdAt)
        noteEntries[index].drawingData = drawingData
        noteEntries[index].updatedAt = .now
        persist()
    }

    func convertDiaryNoteToWorkSiteComment(noteId: String, workSiteId: String) {
        guard let index = noteEntries.firstIndex(where: { $0.id == noteId && $0.type == .diary }),
              let workSite = workSites.first(where: { $0.id == workSiteId }) else { return }

        let conversionDate = Date.now
        noteEntries[index].type = .workSiteComment
        noteEntries[index].title = nextWorkSiteCommentTitle(for: workSite, date: conversionDate)
        noteEntries[index].workSiteId = workSiteId
        noteEntries[index].createdAt = conversionDate
        noteEntries[index].updatedAt = conversionDate

        appendWorkSiteEvent(
            workSiteId: workSiteId,
            type: "worksite_note_created_from_diary",
            title: "Nota de obra",
            summary: "Se ha añadido una nota a \(workSite.name) desde la libreta."
        )

        persist()
    }

    func convertDiaryNoteToInternalMessage(noteId: String) {
        guard let index = noteEntries.firstIndex(where: { $0.id == noteId && $0.type == .diary }) else { return }

        let conversionDate = Date.now
        noteEntries[index].type = .internalMessage
        noteEntries[index].title = normalizedNoteTitle(type: .internalMessage, title: noteEntries[index].title, fallbackDate: conversionDate)
        noteEntries[index].workSiteId = nil
        noteEntries[index].recipientUserIds = []
        noteEntries[index].createdAt = conversionDate
        noteEntries[index].updatedAt = conversionDate
        focusedNoteId = noteId
        managementSection = .notes
        persist()
    }

    func deleteNote(_ noteId: String) {
        guard let index = noteEntries.firstIndex(where: { $0.id == noteId }) else { return }
        let note = noteEntries[index]
        noteEntries.remove(at: index)

        if note.type == .workSiteComment, let workSiteId = note.workSiteId, let workSite = workSites.first(where: { $0.id == workSiteId }) {
            appendWorkSiteEvent(
                workSiteId: workSiteId,
                type: "worksite_note_deleted",
                title: "Nota de obra eliminada",
                summary: "Se ha eliminado una nota del archivo de \(workSite.name)."
            )
        }

        persist()
    }

    func importDocument(from sourceURL: URL, into workSiteId: String) throws {
        guard let workSite = workSites.first(where: { $0.id == workSiteId }) else { return }

        let document = try persistence.importDocument(
            from: sourceURL,
            into: workSiteId,
            createdByUserId: currentUserId
        )

        documentFiles.insert(document, at: 0)
        appendWorkSiteEvent(
            workSiteId: workSiteId,
            type: "document_uploaded",
            title: "Documento subido",
            summary: "Se ha añadido \(document.fileName) al archivo de \(workSite.name)."
        )
        persist()
    }

    func deleteDocument(_ documentId: String) {
        guard let index = documentFiles.firstIndex(where: { $0.id == documentId }) else { return }
        let document = documentFiles[index]
        let workSiteName = workSites.first(where: { $0.id == document.workSiteId })?.name ?? "la obra"

        persistence.deleteDocument(at: document.relativePath)
        documentFiles.remove(at: index)
        appendWorkSiteEvent(
            workSiteId: document.workSiteId,
            type: "document_deleted",
            title: "Documento eliminado",
            summary: "Se ha eliminado \(document.fileName) del archivo de \(workSiteName)."
        )
        persist()
    }

    func documentURL(for document: DocumentFile) -> URL? {
        persistence.documentURL(for: document.relativePath)
    }

    func overwritePDFDocument(_ documentId: String, drawingsByPage: [Int: Data]) throws {
        guard let document = documentFiles.first(where: { $0.id == documentId }),
              document.fileType.lowercased() == "pdf",
              let sourceURL = persistence.documentURL(for: document.relativePath)
        else {
            return
        }

        try persistence.overwritePDF(at: sourceURL, drawingsByPage: drawingsByPage)
        documentAnnotations.removeAll { $0.documentId == documentId }

        appendWorkSiteEvent(
            workSiteId: document.workSiteId,
            type: "document_overwritten",
            title: "PDF sobrescrito",
            summary: "Se ha sobrescrito \(document.fileName) con anotaciones."
        )
        persist()
    }

    func saveAnnotatedPDFCopy(_ documentId: String, drawingsByPage: [Int: Data]) throws {
        guard let sourceDocument = documentFiles.first(where: { $0.id == documentId }),
              sourceDocument.fileType.lowercased() == "pdf",
              let sourceURL = persistence.documentURL(for: sourceDocument.relativePath)
        else {
            return
        }

        let copiedDocument = try persistence.saveAnnotatedPDFCopy(
            from: sourceURL,
            originalDocument: sourceDocument,
            drawingsByPage: drawingsByPage,
            createdByUserId: currentUserId
        )

        documentFiles.insert(copiedDocument, at: 0)
        appendWorkSiteEvent(
            workSiteId: copiedDocument.workSiteId,
            type: "document_copy_created",
            title: "Copia PDF guardada",
            summary: "Se ha guardado una copia anotada de \(sourceDocument.fileName)."
        )
        persist()
    }

    func copyPreviousDay() {
        let previousDate = selectedDate.adding(days: -1)
        ensureDay(previousDate)
        guard let previousState = dailyStates[previousDate.ctrlKey] else { return }
        dailyStates[selectedDate.ctrlKey] = previousState.with(date: selectedDate.ctrlKey)
        persist()
    }

    func copySelectedDayToClipboard() {
        ensureDay(selectedDate)
        copiedDayState = dailyState
    }

    func pasteClipboardIntoSelectedDay() {
        guard let copiedDayState else { return }
        dailyStates[selectedDate.ctrlKey] = copiedDayState.with(date: selectedDate.ctrlKey)
        persist()
    }

    func pasteClipboardIntoCurrentWeek(includeWeekend: Bool = false) {
        guard let copiedDayState else { return }
        let range = includeWeekend ? 0..<7 : 0..<5
        let weekStart = Calendar.ctrl.startOfWeek(for: selectedDate)

        for offset in range {
            let target = weekStart.adding(days: offset)
            dailyStates[target.ctrlKey] = copiedDayState.with(date: target.ctrlKey)
        }

        persist()
    }

    private func ensureDay(_ date: Date) {
        if dailyStates[date.ctrlKey] == nil {
            dailyStates[date.ctrlKey] = MockData.seedDailyState(for: date, employees: employees, workSites: workSites)
            persist()
            return
        }

        let activeIds = Set(workSites.filter(\.isActive).map(\.id))
        if var state = dailyStates[date.ctrlKey] {
            let sanitizedVisibleIds = state.visibleWorkSiteIds.filter { activeIds.contains($0) }
            if sanitizedVisibleIds != state.visibleWorkSiteIds {
                state.visibleWorkSiteIds = sanitizedVisibleIds
                dailyStates[date.ctrlKey] = state
                persist()
            }
        }
    }

    private func mutateDailyState(for date: Date, mutate: (inout DailyState) -> Void) {
        ensureDay(date)
        guard var state = dailyStates[date.ctrlKey] else { return }
        mutate(&state)
        dailyStates[date.ctrlKey] = state
        persist()
    }

    private func persist() {
        let snapshot = DailyBoardSnapshot(
            selectedDate: selectedDate.ctrlKey,
            users: users,
            employees: employees,
            workSites: workSites,
            dailyStates: dailyStates,
            noteEntries: noteEntries,
            documentAnnotations: documentAnnotations,
            documentFiles: documentFiles,
            workSiteEvents: workSiteEvents
        )
        persistence.save(snapshot)
        persistence.syncNoteDocuments(noteEntries)
    }

    private static let palette = [
        "#22C55E",
        "#84CC16",
        "#38BDF8",
        "#F97316",
        "#14B8A6",
        "#EAB308"
    ]

    private let workSiteCoordinates: [String: CLLocationCoordinate2D] = [
        "malaga": CLLocationCoordinate2D(latitude: 36.7213, longitude: -4.4214),
        "madrid": CLLocationCoordinate2D(latitude: 40.4168, longitude: -3.7038),
        "bilbao": CLLocationCoordinate2D(latitude: 43.2630, longitude: -2.9350),
        "zaragoza": CLLocationCoordinate2D(latitude: 41.6488, longitude: -0.8891),
        "valencia": CLLocationCoordinate2D(latitude: 39.4699, longitude: -0.3763),
        "sevilla": CLLocationCoordinate2D(latitude: 37.3891, longitude: -5.9845),
        "granada": CLLocationCoordinate2D(latitude: 37.1773, longitude: -3.5986),
        "cadiz": CLLocationCoordinate2D(latitude: 36.5271, longitude: -6.2886),
        "cordoba": CLLocationCoordinate2D(latitude: 37.8882, longitude: -4.7794),
        "barcelona": CLLocationCoordinate2D(latitude: 41.3874, longitude: 2.1686),
        "alicante": CLLocationCoordinate2D(latitude: 38.3452, longitude: -0.4810),
        "murcia": CLLocationCoordinate2D(latitude: 37.9922, longitude: -1.1307),
        "vigo": CLLocationCoordinate2D(latitude: 42.2406, longitude: -8.7207),
        "a coruna": CLLocationCoordinate2D(latitude: 43.3623, longitude: -8.4115),
        "la coruna": CLLocationCoordinate2D(latitude: 43.3623, longitude: -8.4115),
        "oviedo": CLLocationCoordinate2D(latitude: 43.3614, longitude: -5.8494),
        "gijon": CLLocationCoordinate2D(latitude: 43.5322, longitude: -5.6611),
        "palma": CLLocationCoordinate2D(latitude: 39.5696, longitude: 2.6502)
    ]

    private func nearestVisibleWorkSite(to coordinate: CLLocationCoordinate2D) -> WorkSite? {
        let visibleIds = Set(dailyState.visibleWorkSiteIds)
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        return workSites
            .filter { visibleIds.contains($0.id) && $0.isActive }
            .map { workSite in
                let destination = CLLocation(latitude: workSite.lat, longitude: workSite.lng)
                return (workSite, origin.distance(from: destination))
            }
            .filter { $0.1 <= 30_000 }
            .sorted { $0.1 < $1.1 }
            .first?
            .0
    }

    private func makeUniqueWorkSiteCode() -> String {
        var code = String(Int.random(in: 10_000_000...99_999_999))
        let existingCodes = Set(workSites.map(\.internalCode))

        while existingCodes.contains(code) {
            code = String(Int.random(in: 10_000_000...99_999_999))
        }

        return code
    }

    private func coordinateForLocation(city: String, addressLine: String?) async -> CLLocationCoordinate2D {
        if let geocodedCoordinate = await geocode(city: city, addressLine: addressLine) {
            return geocodedCoordinate
        }

        let normalizedCity = city.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        let base = workSiteCoordinates[normalizedCity] ?? CLLocationCoordinate2D(latitude: 40.4168, longitude: -3.7038)

        guard let addressLine, !addressLine.isEmpty else {
            return base
        }

        let offsetSeed = abs(addressLine.hashValue % 1000)
        let offset = Double(offsetSeed) / 100_000
        return CLLocationCoordinate2D(latitude: base.latitude + offset, longitude: base.longitude - offset)
    }

    private func geocode(city: String, addressLine: String?) async -> CLLocationCoordinate2D? {
        let geocoder = CLGeocoder()
        let locationText = [addressLine, city, "España"]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        guard !locationText.isEmpty else { return nil }

        do {
            let placemarks = try await geocoder.geocodeAddressString(locationText)
            if let coordinate = placemarks.first?.location?.coordinate {
                return coordinate
            }
        } catch {
        }

        return nil
    }

    private func appendWorkSiteEvent(workSiteId: String, type: String, title: String, summary: String) {
        workSiteEvents.insert(
            WorkSiteEvent(
                id: "wse-\(UUID().uuidString.lowercased())",
                workSiteId: workSiteId,
                createdAt: .now,
                createdByUserId: currentUserId,
                type: type,
                title: title,
                summary: summary
            ),
            at: 0
        )
    }

    private func normalizedNoteTitle(type: NoteEntryType, title: String, fallbackDate: Date? = nil) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }

        switch type {
        case .diary:
            return nextDiaryTitle(for: fallbackDate ?? selectedDate)
        case .workSiteComment:
            return "Comentario de obra"
        case .internalMessage:
            return "Comunicado interno"
        }
    }

    private func nextDiaryTitle(for date: Date) -> String {
        guard let currentUserId else { return date.longSpanishTitle }

        let dayStart = Calendar.ctrl.startOfDay(for: date)
        let existingCount = noteEntries.filter {
            $0.type == .diary &&
            $0.createdByUserId == currentUserId &&
            Calendar.ctrl.isDate($0.createdAt, inSameDayAs: dayStart)
        }.count

        if existingCount == 0 {
            return dayStart.longSpanishTitle
        }

        return "\(dayStart.longSpanishTitle) (\(existingCount + 1))"
    }

    private func nextWorkSiteCommentTitle(for workSite: WorkSite, date: Date) -> String {
        let dayStart = Calendar.ctrl.startOfDay(for: date)
        let baseTitle = "\(workSite.name) · \(dayStart.longSpanishTitle)"
        let existingCount = noteEntries.filter {
            $0.type == .workSiteComment &&
            $0.workSiteId == workSite.id &&
            Calendar.ctrl.isDate($0.createdAt, inSameDayAs: dayStart)
        }.count

        if existingCount == 0 {
            return baseTitle
        }

        return "\(baseTitle) (\(existingCount + 1))"
    }

    private static func currentSpainTimeText() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone(identifier: "Europe/Madrid")
        formatter.dateFormat = "H:mm:ss"
        return formatter.string(from: .now)
    }

    private func startClock() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.spainTimeText = Self.currentSpainTimeText()
            }
        }
    }
}

private struct AuthSessionPersistence {
    private let rememberedUserIdKey = "ctrl.remembered-user-id"

    func loadRememberedUserId() -> String? {
        UserDefaults.standard.string(forKey: rememberedUserIdKey)
    }

    func saveRememberedUserId(_ userId: String) {
        UserDefaults.standard.set(userId, forKey: rememberedUserIdKey)
    }

    func clearRememberedUserId() {
        UserDefaults.standard.removeObject(forKey: rememberedUserIdKey)
    }
}

private struct DailyBoardPersistence {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func load() -> DailyBoardSnapshot? {
        guard
            let url = fileURL,
            let data = try? Data(contentsOf: url),
            let snapshot = try? decoder.decode(DailyBoardSnapshot.self, from: data)
        else {
            return nil
        }

        return snapshot
    }

    func save(_ snapshot: DailyBoardSnapshot) {
        guard let url = fileURL else { return }

        do {
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: .atomic)
        } catch {
            assertionFailure("CTRL persistence failed: \(error)")
        }
    }

    func loadNoteDocuments(fallback: [NoteEntry]) -> [NoteEntry] {
        let fallbackById = Dictionary(uniqueKeysWithValues: fallback.map { ($0.id, $0) })
        guard let notesDirectory else { return fallback }

        let folderURLs = (try? FileManager.default.contentsOfDirectory(
            at: notesDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        var loadedById = fallbackById

        for folderURL in folderURLs {
            let metadataURL = folderURL.appendingPathComponent("metadata.json")
            guard let data = try? Data(contentsOf: metadataURL),
                  var note = try? decoder.decode(NoteEntry.self, from: data) else {
                continue
            }

            let drawingURL = folderURL.appendingPathComponent("drawing.data")
            if let drawingData = try? Data(contentsOf: drawingURL), !drawingData.isEmpty {
                note.drawingData = drawingData
            } else {
                note.drawingData = nil
            }

            loadedById[note.id] = note
        }

        return Array(loadedById.values)
    }

    func syncNoteDocuments(_ notes: [NoteEntry]) {
        guard let notesDirectory else { return }

        do {
            try FileManager.default.createDirectory(at: notesDirectory, withIntermediateDirectories: true)

            let currentIds = Set(notes.map(\.id))
            let existingFolders = (try? FileManager.default.contentsOfDirectory(
                at: notesDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []

            for folderURL in existingFolders where !currentIds.contains(folderURL.lastPathComponent) {
                try? FileManager.default.removeItem(at: folderURL)
            }

            for note in notes {
                try saveNoteDocument(note, in: notesDirectory)
            }
        } catch {
            assertionFailure("CTRL note persistence failed: \(error)")
        }
    }

    func importDocument(from sourceURL: URL, into workSiteId: String, createdByUserId: String?) throws -> DocumentFile {
        let accessGranted = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let directory = try documentsDirectory(for: workSiteId)
        let originalName = sourceURL.lastPathComponent
        let fileExtension = sourceURL.pathExtension.lowercased()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let storedName = fileExtension.isEmpty
            ? "\(baseName)-\(UUID().uuidString)"
            : "\(baseName)-\(UUID().uuidString).\(fileExtension)"
        let destinationURL = directory.appendingPathComponent(storedName)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        return DocumentFile(
            id: "doc-\(UUID().uuidString.lowercased())",
            workSiteId: workSiteId,
            fileName: originalName,
            fileType: fileExtension.isEmpty ? "file" : fileExtension,
            relativePath: "documents/\(workSiteId)/\(storedName)",
            createdAt: .now,
            createdByUserId: createdByUserId
        )
    }

    func deleteDocument(at relativePath: String) {
        guard !relativePath.isEmpty, let rootDirectory = rootDirectory else { return }
        let fileURL = rootDirectory.appendingPathComponent(relativePath)
        try? FileManager.default.removeItem(at: fileURL)
    }

    func overwritePDF(at fileURL: URL, drawingsByPage: [Int: Data]) throws {
        let renderedData = try renderedPDFData(from: fileURL, drawingsByPage: drawingsByPage)
        try renderedData.write(to: fileURL, options: .atomic)
    }

    func saveAnnotatedPDFCopy(
        from sourceURL: URL,
        originalDocument: DocumentFile,
        drawingsByPage: [Int: Data],
        createdByUserId: String?
    ) throws -> DocumentFile {
        let renderedData = try renderedPDFData(from: sourceURL, drawingsByPage: drawingsByPage)
        let directory = try documentsDirectory(for: originalDocument.workSiteId)
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let storedName = "\(baseName)-anotado-\(UUID().uuidString).pdf"
        let destinationURL = directory.appendingPathComponent(storedName)
        try renderedData.write(to: destinationURL, options: .atomic)

        return DocumentFile(
            id: "doc-\(UUID().uuidString.lowercased())",
            workSiteId: originalDocument.workSiteId,
            fileName: "\(baseName)-anotado.pdf",
            fileType: "pdf",
            relativePath: "documents/\(originalDocument.workSiteId)/\(storedName)",
            createdAt: .now,
            createdByUserId: createdByUserId
        )
    }

    func documentURL(for relativePath: String) -> URL? {
        guard !relativePath.isEmpty, let rootDirectory = rootDirectory else { return nil }
        return rootDirectory.appendingPathComponent(relativePath)
    }

    private var fileURL: URL? {
        do {
            guard let directory = rootDirectory else { return nil }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory.appendingPathComponent("daily-board.json")
        } catch {
            return nil
        }
    }

    private var rootDirectory: URL? {
        do {
            let applicationSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            return applicationSupport.appendingPathComponent("CTRL", isDirectory: true)
        } catch {
            return nil
        }
    }

    private var notesDirectory: URL? {
        rootDirectory?.appendingPathComponent("notes", isDirectory: true)
    }

    private func documentsDirectory(for workSiteId: String) throws -> URL {
        guard let rootDirectory else {
            throw CocoaError(.fileNoSuchFile)
        }

        let directory = rootDirectory
            .appendingPathComponent("documents", isDirectory: true)
            .appendingPathComponent(workSiteId, isDirectory: true)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func saveNoteDocument(_ note: NoteEntry, in notesDirectory: URL) throws {
        let noteDirectory = notesDirectory.appendingPathComponent(note.id, isDirectory: true)
        try FileManager.default.createDirectory(at: noteDirectory, withIntermediateDirectories: true)

        var metadata = note
        metadata.drawingData = nil

        let metadataURL = noteDirectory.appendingPathComponent("metadata.json")
        let drawingURL = noteDirectory.appendingPathComponent("drawing.data")
        let previewURL = noteDirectory.appendingPathComponent("preview.jpg")

        let metadataData = try encoder.encode(metadata)
        try metadataData.write(to: metadataURL, options: .atomic)

        if let drawingData = note.drawingData, !drawingData.isEmpty {
            try drawingData.write(to: drawingURL, options: .atomic)

            if let previewImage = notePreviewImage(from: drawingData),
               let jpegData = previewImage.jpegData(compressionQuality: 0.72) {
                try jpegData.write(to: previewURL, options: .atomic)
            }
        } else {
            try? FileManager.default.removeItem(at: drawingURL)
            try? FileManager.default.removeItem(at: previewURL)
        }
    }

    private func renderedPDFData(from fileURL: URL, drawingsByPage: [Int: Data]) throws -> Data {
        guard let inputDocument = PDFDocument(url: fileURL) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let outputData = NSMutableData()
        guard let consumer = CGDataConsumer(data: outputData as CFMutableData) else {
            throw CocoaError(.fileWriteUnknown)
        }

        var mediaBox = CGRect(x: 0, y: 0, width: 1, height: 1)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }

        for pageIndex in 0..<inputDocument.pageCount {
            guard let page = inputDocument.page(at: pageIndex) else { continue }
            let pageBounds = page.bounds(for: .mediaBox)
            var pageBox = pageBounds
            context.beginPage(mediaBox: &pageBox)

            context.saveGState()
            context.translateBy(x: 0, y: pageBounds.height)
            context.scaleBy(x: 1, y: -1)
            if let pageRef = page.pageRef {
                context.drawPDFPage(pageRef)
            }
            context.restoreGState()

            if let drawingData = drawingsByPage[pageIndex],
               let drawing = try? PKDrawing(data: drawingData) {
                let image = drawing.image(from: pageBounds, scale: 1)
                if let cgImage = image.cgImage {
                    context.saveGState()
                    context.translateBy(x: 0, y: pageBounds.height)
                    context.scaleBy(x: 1, y: -1)
                    context.draw(cgImage, in: pageBounds)
                    context.restoreGState()
                }
            }

            context.endPage()
        }

        context.closePDF()
        return outputData as Data
    }

    private func notePreviewImage(from drawingData: Data) -> UIImage? {
        guard let drawing = try? PKDrawing(data: drawingData) else {
            return nil
        }

        let bounds = CGRect(x: 0, y: 0, width: 1200, height: 1600)
        return drawing.image(from: bounds, scale: 1)
    }
}

private extension DailyState {
    func with(date: String) -> DailyState {
        DailyState(
            date: date,
            notes: notes,
            visibleWorkSiteIds: visibleWorkSiteIds,
            employeePlacements: employeePlacements,
            absentEmployeeIds: absentEmployeeIds
        )
    }
}
