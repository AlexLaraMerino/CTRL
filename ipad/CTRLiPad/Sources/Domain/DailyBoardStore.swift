import CoreLocation
import Foundation

@MainActor
final class DailyBoardStore: ObservableObject {
    @Published var selectedDate: Date
    @Published var users: [User]
    @Published var employees: [Employee]
    @Published var workSites: [WorkSite]
    @Published var dailyStates: [String: DailyState]
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
        let initialDocumentFiles: [DocumentFile]
        let initialWorkSiteEvents: [WorkSiteEvent]

        if let snapshot = persistence.load() {
            initialSelectedDate = Date(ctrlKey: snapshot.selectedDate) ?? .now
            initialUsers = snapshot.users
            initialEmployees = snapshot.employees
            initialWorkSites = snapshot.workSites
            initialDailyStates = snapshot.dailyStates
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
            initialDocumentFiles = []
            initialWorkSiteEvents = []
        }

        self.selectedDate = initialSelectedDate
        self.users = initialUsers
        self.employees = initialEmployees
        self.workSites = initialWorkSites
        self.dailyStates = initialDailyStates
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

    func addWorkSite(name: String, city: String, addressLine: String = "") {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = addressLine.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty, !trimmedCity.isEmpty else { return }

        let coordinate = coordinateForLocation(city: trimmedCity, addressLine: trimmedAddress.isEmpty ? nil : trimmedAddress)
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

    func updateWorkSite(_ workSiteId: String, name: String, city: String, addressLine: String = "") {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = addressLine.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty, !trimmedCity.isEmpty else { return }
        guard let index = workSites.firstIndex(where: { $0.id == workSiteId }) else { return }

        let coordinate = coordinateForLocation(city: trimmedCity, addressLine: trimmedAddress.isEmpty ? nil : trimmedAddress)
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
            documentFiles: documentFiles,
            workSiteEvents: workSiteEvents
        )
        persistence.save(snapshot)
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

    private func coordinateForLocation(city: String, addressLine: String?) -> CLLocationCoordinate2D {
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

    private var fileURL: URL? {
        do {
            let root = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let directory = root.appendingPathComponent("CTRL", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory.appendingPathComponent("daily-board.json")
        } catch {
            return nil
        }
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
