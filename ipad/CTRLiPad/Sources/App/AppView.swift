import MapKit
import SwiftUI

struct AppView: View {
    @EnvironmentObject private var store: DailyBoardStore
    @State private var managementTransitionInFlight = false

    var body: some View {
        Group {
            if store.currentUser == nil {
                LoginView()
            } else {
                MainMapView(
                    onOpenManagement: openManagement
                )
                    .fullScreenCover(isPresented: Binding(
                        get: { store.managementVisible },
                        set: { store.managementVisible = $0 }
                    )) {
                        ManagementView(
                            onClose: closeManagement,
                            onLogout: logoutFromManagement
                        )
                            .environmentObject(store)
                    }
            }
        }
        .onAppear {
            applyOrientation()
        }
        .onChange(of: store.currentUserId) { _, _ in
            applyOrientation()
        }
        .onChange(of: store.managementVisible) { _, _ in
            applyOrientation()
        }
        .onChange(of: store.managementRequestID) { _, _ in
            guard store.currentUser != nil, !store.managementVisible else { return }
            openManagement()
        }
    }

    private func applyOrientation() {
        if store.currentUser == nil {
            OrientationController.shared.set(mask: .landscape, preferred: .landscapeLeft)
        } else if store.managementVisible {
            OrientationController.shared.set(mask: .portrait, preferred: .portrait)
        } else {
            OrientationController.shared.set(mask: .landscape, preferred: .landscapeLeft)
        }
    }

    private func openManagement() {
        guard !managementTransitionInFlight else { return }

        managementTransitionInFlight = true
        OrientationController.shared.set(mask: .portrait, preferred: .portrait)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            store.managementVisible = true
            managementTransitionInFlight = false
        }
    }

    private func closeManagement() {
        guard !managementTransitionInFlight else { return }

        managementTransitionInFlight = true
        store.managementVisible = false
        store.closeManagementContext()

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            OrientationController.shared.set(mask: .landscape, preferred: .landscapeLeft)
            managementTransitionInFlight = false
        }
    }

    private func logoutFromManagement() {
        guard !managementTransitionInFlight else { return }

        managementTransitionInFlight = true
        store.managementVisible = false
        store.closeManagementContext()

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            store.logout()
            OrientationController.shared.set(mask: .landscape, preferred: .landscapeLeft)
            managementTransitionInFlight = false
        }
    }
}

private struct MainMapView: View {
    @EnvironmentObject private var store: DailyBoardStore
    let onOpenManagement: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                OperationalMapView()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    HeaderBar()
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    Spacer()
                }

                HStack(spacing: 0) {
                    if store.leftPanelVisible {
                        AgendaPanel(width: min(340, proxy.size.width * 0.32))
                            .padding(.leading, 16)
                            .padding(.top, 88)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }

                    Spacer()

                    VStack(spacing: 12) {
                        if store.rightPanel == .employees {
                            EmployeesPanel(width: min(360, proxy.size.width * 0.34))
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }

                        if store.rightPanel == .workSites {
                            WorkSitesPanel(width: min(380, proxy.size.width * 0.36))
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 88)
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button("Gestión") {
                            store.openManagementHome()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .padding(.trailing, 16)
                        .padding(.bottom, 22)
                        .opacity(store.leftPanelVisible || store.rightPanel != .none ? 0 : 1)
                        .allowsHitTesting(!(store.leftPanelVisible || store.rightPanel != .none))
                    }
                }
            }
            .background(Color.ctrlBackground)
            .animation(.easeInOut(duration: 0.2), value: store.leftPanelVisible)
            .animation(.easeInOut(duration: 0.2), value: store.rightPanel)
        }
    }
}

private struct HeaderBar: View {
    @EnvironmentObject private var store: DailyBoardStore

    var body: some View {
        HStack(spacing: 12) {
            SmallEdgeButton(title: "Agenda") {
                store.leftPanelVisible.toggle()
            }

            Text(store.selectedDate.longSpanishTitle)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            Text("ES \(store.spainTimeText)")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ctrlMuted)

            SmallEdgeButton(title: "-1") {
                store.shiftSelectedDate(by: -1)
            }

            SmallEdgeButton(title: "Hoy") {
                store.goToToday()
            }

            SmallEdgeButton(title: "+1") {
                store.shiftSelectedDate(by: 1)
            }

            SmallEdgeButton(title: "Operarios") {
                store.rightPanel = store.rightPanel == .employees ? .none : .employees
            }

            SmallEdgeButton(title: "Obras") {
                store.rightPanel = store.rightPanel == .workSites ? .none : .workSites
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct SmallEdgeButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.ctrlPanel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct AgendaPanel: View {
    @EnvironmentObject private var store: DailyBoardStore
    let width: CGFloat

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Agenda")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                MonthlyCalendarView(
                    month: store.calendarMonth,
                    selectedDate: store.selectedDate,
                    onPreviousMonth: { store.shiftCalendarMonth(by: -1) },
                    onNextMonth: { store.shiftCalendarMonth(by: 1) },
                    onSelect: { store.selectDate($0) }
                )

                VStack(alignment: .leading, spacing: 10) {
                    ActionChip(title: "Copiar ayer", fullWidth: true) {
                        store.copyPreviousDay()
                    }

                    ActionChip(title: "Copiar día", fullWidth: true) {
                        store.copySelectedDayToClipboard()
                    }

                    ActionChip(title: "Pegar día", fullWidth: true, disabled: store.copiedDayState == nil) {
                        store.pasteClipboardIntoSelectedDay()
                    }

                    ActionChip(title: "Pegar semana", fullWidth: true, disabled: store.copiedDayState == nil) {
                        store.pasteClipboardIntoCurrentWeek()
                    }
                }
            }
            .padding(20)
        }
        .frame(width: width)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct EmployeesPanel: View {
    @EnvironmentObject private var store: DailyBoardStore
    @State private var expandedEmployeeId: String?
    @State private var inactiveOpen = false
    @State private var drafts: [String: String] = [:]
    let width: CGFloat

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Operarios")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                ForEach(store.activeEmployees) { employee in
                    EmployeeRow(
                        employee: employee,
                        draft: Binding(
                            get: { drafts[employee.id] ?? employee.name },
                            set: { drafts[employee.id] = $0 }
                        ),
                        expanded: expandedEmployeeId == employee.id,
                        onToggleExpand: {
                            expandedEmployeeId = expandedEmployeeId == employee.id ? nil : employee.id
                        }
                    )
                }

                NewEmployeeRow()

                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        inactiveOpen.toggle()
                    } label: {
                        HStack {
                            Text("Operarios inactivos")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Spacer()

                            Image(systemName: inactiveOpen ? "chevron.up" : "chevron.down")
                                .foregroundStyle(Color.ctrlMuted)
                        }
                        .padding(16)
                        .background(Color.ctrlPanelSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    if inactiveOpen {
                        ForEach(store.inactiveEmployees) { employee in
                            InactiveEmployeeRow(employee: employee)
                        }
                    }
                }
            }
            .padding(20)
        }
        .frame(width: width)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct EmployeeRow: View {
    @EnvironmentObject private var store: DailyBoardStore
    let employee: Employee
    @Binding var draft: String
    let expanded: Bool
    let onToggleExpand: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                onToggleExpand()
            } label: {
                HStack(spacing: 12) {
                    Circle()
                        .fill(employee.color)
                        .frame(width: 12, height: 12)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(employee.name)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(store.isEmployeeAbsent(employee.id) ? "Ausente hoy" : "Pulsa para desplegar acciones")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ctrlMuted)
                    }

                    Spacer()

                    if store.relocation.employeeId == employee.id {
                        Image(systemName: "hand.draw.fill")
                            .foregroundStyle(Color.ctrlAccent)
                    }

                    Image(systemName: expanded ? "minus" : "plus")
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)

            if expanded {
                TextField("Nombre", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(Color.ctrlPanel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        EmployeeActionCard(
                            icon: "hand.draw.fill",
                            title: "Colocar",
                            description: "Seleccionar y llevar al mapa"
                        ) {
                            store.rightPanel = .none
                            store.prepareRelocation(for: employee.id)
                        }

                        EmployeeActionCard(
                            icon: "pencil",
                            title: "Guardar",
                            description: "Actualizar nombre"
                        ) {
                            store.updateEmployeeName(employee.id, name: draft)
                        }

                        EmployeeActionCard(
                            icon: "moon.zzz.fill",
                            title: store.isEmployeeAbsent(employee.id) ? "Activar hoy" : "Ausencia",
                            description: store.isEmployeeAbsent(employee.id) ? "Volver al mapa hoy" : "Ocultarlo solo hoy"
                        ) {
                            store.toggleEmployeeAbsence(employee.id)
                        }

                        EmployeeActionCard(
                            icon: "pause.circle.fill",
                            title: "Desactivar",
                            description: "Mover a inactivos"
                        ) {
                            store.setEmployeeActive(employee.id, isActive: false)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.ctrlPanelSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct InactiveEmployeeRow: View {
    @EnvironmentObject private var store: DailyBoardStore
    let employee: Employee

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(employee.color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(employee.name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Operario inactivo")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ctrlMuted)
            }

            Spacer()

            Button("Activar") {
                store.setEmployeeActive(employee.id, isActive: true)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.ctrlAccent)
        }
        .padding(16)
        .background(Color.ctrlPanelSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct EmployeeActionCard: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(.white)
                    .font(.system(size: 18, weight: .bold))

                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(description)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ctrlMuted)
                    .multilineTextAlignment(.leading)
            }
            .frame(width: 150, alignment: .topLeading)
            .frame(minHeight: 112, alignment: .topLeading)
            .padding(12)
            .background(Color.ctrlPanel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct NewEmployeeRow: View {
    @EnvironmentObject private var store: DailyBoardStore
    @State private var draft = ""

    var body: some View {
        HStack(spacing: 10) {
            TextField("Nombre del operario", text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(Color.ctrlPanelSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button("Añadir") {
                store.addEmployee(named: draft)
                draft = ""
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.ctrlAccent)
        }
    }
}

private struct WorkSitesPanel: View {
    @EnvironmentObject private var store: DailyBoardStore
    @State private var query = ""
    @State private var expandedWorkSiteId: String?
    @State private var inactiveOpen = false
    @State private var nameDrafts: [String: String] = [:]
    @State private var cityDrafts: [String: String] = [:]
    @State private var addressDrafts: [String: String] = [:]
    let width: CGFloat

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Obras")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                TextField("Buscar obra", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(Color.ctrlPanelSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                ForEach(filteredActiveWorkSites) { workSite in
                    WorkSiteRow(
                        workSite: workSite,
                        nameDraft: Binding(
                            get: { nameDrafts[workSite.id] ?? workSite.name },
                            set: { nameDrafts[workSite.id] = $0 }
                        ),
                        cityDraft: Binding(
                            get: { cityDrafts[workSite.id] ?? workSite.city },
                            set: { cityDrafts[workSite.id] = $0 }
                        ),
                        addressDraft: Binding(
                            get: { addressDrafts[workSite.id] ?? (workSite.addressLine ?? "") },
                            set: { addressDrafts[workSite.id] = $0 }
                        ),
                        expanded: expandedWorkSiteId == workSite.id,
                        onToggleExpand: {
                            expandedWorkSiteId = expandedWorkSiteId == workSite.id ? nil : workSite.id
                        }
                    )
                }

                NewWorkSiteRow()

                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        inactiveOpen.toggle()
                    } label: {
                        HStack {
                            Text("Obras inactivas")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Spacer()

                            Image(systemName: inactiveOpen ? "chevron.up" : "chevron.down")
                                .foregroundStyle(Color.ctrlMuted)
                        }
                        .padding(16)
                        .background(Color.ctrlPanelSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    if inactiveOpen {
                        ForEach(filteredInactiveWorkSites) { workSite in
                            InactiveWorkSiteRow(workSite: workSite)
                        }
                    }
                }
            }
            .padding(20)
        }
        .frame(width: width)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var filteredActiveWorkSites: [WorkSite] {
        store.activeWorkSites.filter(matchesSearch)
    }

    private var filteredInactiveWorkSites: [WorkSite] {
        store.inactiveWorkSites.filter(matchesSearch)
    }

    private func matchesSearch(_ workSite: WorkSite) -> Bool {
        guard !query.isEmpty else { return true }

        return workSite.name.localizedCaseInsensitiveContains(query)
            || workSite.city.localizedCaseInsensitiveContains(query)
            || workSite.internalCode.localizedCaseInsensitiveContains(query)
            || (workSite.addressLine?.localizedCaseInsensitiveContains(query) ?? false)
    }
}

private struct WorkSiteRow: View {
    @EnvironmentObject private var store: DailyBoardStore
    let workSite: WorkSite
    @Binding var nameDraft: String
    @Binding var cityDraft: String
    @Binding var addressDraft: String
    let expanded: Bool
    let onToggleExpand: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                onToggleExpand()
            } label: {
                HStack(spacing: 12) {
                    Circle()
                        .fill(store.dailyState.visibleWorkSiteIds.contains(workSite.id) ? Color.orange : Color.ctrlMuted)
                        .frame(width: 12, height: 12)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(workSite.name)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("\(workSite.city) · \(workSite.internalCode)")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ctrlMuted)
                    }

                    Spacer()

                    Image(systemName: expanded ? "minus" : "plus")
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(spacing: 10) {
                    TextField("Ciudad o pueblo", text: $cityDraft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(Color.ctrlPanel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    TextField("Calle o referencia opcional", text: $addressDraft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(Color.ctrlPanel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    TextField("Nombre de la obra", text: $nameDraft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(Color.ctrlPanel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Toggle(isOn: Binding(
                        get: { store.dailyState.visibleWorkSiteIds.contains(workSite.id) },
                        set: { _ in store.toggleWorkSiteVisibility(workSite.id) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Visible hoy")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Text("Mostrar u ocultar esta obra en el mapa")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.ctrlMuted)
                        }
                    }
                    .tint(Color.ctrlAccent)
                    .padding(14)
                    .background(Color.ctrlPanel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            WorkSiteActionCard(
                                icon: "pencil",
                                title: "Modificar",
                                description: "Guardar nombre y ubicación"
                            ) {
                                Task {
                                    await store.updateWorkSite(
                                        workSite.id,
                                        name: nameDraft,
                                        city: cityDraft,
                                        addressLine: addressDraft
                                    )
                                }
                            }

                            WorkSiteActionCard(
                                icon: "pause.circle.fill",
                                title: "Desactivar",
                                description: "Mover a inactivas"
                            ) {
                                store.setWorkSiteActive(workSite.id, isActive: false)
                            }

                            WorkSiteActionCard(
                                icon: "folder.fill",
                                title: "Archivo",
                                description: "Abrir archivo"
                            ) {
                                store.rightPanel = .none
                                store.openManagement(section: .archive, workSiteId: workSite.id)
                            }

                            WorkSiteActionCard(
                                icon: "clock.arrow.circlepath",
                                title: "Historial",
                                description: "Ver eventos"
                            ) {
                                store.rightPanel = .none
                                store.openManagement(section: .history, workSiteId: workSite.id)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.ctrlPanelSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct InactiveWorkSiteRow: View {
    @EnvironmentObject private var store: DailyBoardStore
    let workSite: WorkSite

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.ctrlMuted)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(workSite.name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("\(workSite.city) · \(workSite.internalCode)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ctrlMuted)
            }

            Spacer()

            Button("Activar") {
                store.setWorkSiteActive(workSite.id, isActive: true)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.ctrlAccent)
        }
        .padding(16)
        .background(Color.ctrlPanelSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct WorkSiteActionCard: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(.white)
                    .font(.system(size: 18, weight: .bold))

                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(description)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ctrlMuted)
                    .multilineTextAlignment(.leading)
            }
            .frame(width: 150, alignment: .topLeading)
            .frame(minHeight: 112, alignment: .topLeading)
            .padding(12)
            .background(Color.ctrlPanel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct NewWorkSiteRow: View {
    @EnvironmentObject private var store: DailyBoardStore
    @State private var city = ""
    @State private var address = ""
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nueva obra")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            TextField("Ciudad o pueblo", text: $city)
                .textFieldStyle(.plain)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(Color.ctrlPanelSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            TextField("Calle o referencia opcional", text: $address)
                .textFieldStyle(.plain)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(Color.ctrlPanelSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            HStack(spacing: 10) {
                TextField("Nombre de la obra", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(Color.ctrlPanelSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                Button("Crear") {
                    Task {
                        await store.addWorkSite(name: name, city: city, addressLine: address)
                        city = ""
                        address = ""
                        name = ""
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.ctrlAccent)
            }
        }
        .padding(16)
        .background(Color.ctrlPanel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct ActionChip: View {
    let title: String
    var fullWidth = false
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: fullWidth ? .infinity : nil, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.ctrlPanelSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }
}

private struct MonthlyCalendarView: View {
    let month: Date
    let selectedDate: Date
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onSelect: (Date) -> Void

    private let calendar = Calendar.ctrl

    var body: some View {
        let monthDays = calendar.gridDays(for: month)
        let weekSymbols = calendar.veryShortWeekdaySymbolsShifted

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: onPreviousMonth) {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.ctrlPanel, in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(month.monthTitleUppercased)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                Button(action: onNextMonth) {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.ctrlPanel, in: Circle())
                }
                .buttonStyle(.plain)
            }

            HStack {
                ForEach(weekSymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ctrlMuted)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(monthDays, id: \.self) { day in
                    Button {
                        onSelect(day)
                    } label: {
                        Text(day.dayNumberText)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(calendar.isDate(day, equalTo: month, toGranularity: .month) ? .white : Color.ctrlMuted.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(
                                Circle()
                                    .fill(calendar.isDate(day, inSameDayAs: selectedDate) ? Color.ctrlAccent : .clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(Color.ctrlPanelSoft, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
