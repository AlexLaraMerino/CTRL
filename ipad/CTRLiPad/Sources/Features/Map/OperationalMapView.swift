import MapKit
import SwiftUI
import UIKit

struct OperationalMapView: View {
    @EnvironmentObject private var store: DailyBoardStore
    @State private var dragCoordinate: CLLocationCoordinate2D?
    @State private var hoveredWorkSiteId: String?
    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.1668, longitude: -3.7038),
            span: MKCoordinateSpan(latitudeDelta: 9.5, longitudeDelta: 11.0)
        )
    )

    var body: some View {
        MapReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                Map(position: $position) {
                    ForEach(visibleWorkSites) { workSite in
                        Annotation(workSite.city, coordinate: workSite.coordinate) {
                            WorkSiteBadge(
                                workSite: workSite,
                                assignedCount: assignedCount(for: workSite.id),
                                highlighted: hoveredWorkSiteId == workSite.id
                            )
                        }
                    }

                    ForEach(displayedEmployees) { employee in
                        if let placement = placementFor(employee.id), shouldRenderEmployeeOnMap(employee.id) {
                            Annotation(employee.name, coordinate: placement.coordinate) {
                                EmployeeOverlayBadge(
                                    employee: employee,
                                    selected: store.relocation.employeeId == employee.id,
                                    compact: false
                                )
                                .onTapGesture {
                                    store.prepareRelocation(for: employee.id)
                                }
                                .simultaneousGesture(
                                    LongPressGesture(minimumDuration: 0.35)
                                        .onEnded { _ in
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            store.prepareRelocation(for: employee.id)
                                        }
                                )
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))

                if let selectedEmployee = selectedEmployeeForPlacement {
                    GeometryReader { _ in
                        ZStack {
                            if let coordinate = dragCoordinate ?? placementFor(selectedEmployee.id)?.coordinate,
                               let point = proxy.convert(coordinate, to: .local) {
                                EmployeeOverlayBadge(
                                    employee: selectedEmployee,
                                    selected: true,
                                    compact: false
                                )
                                .position(x: point.x, y: point.y)
                            }

                            Color.clear
                                .contentShape(Rectangle())
                                .highPriorityGesture(
                                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                                        .onChanged { value in
                                            guard let coordinate = proxy.convert(value.location, from: .local) else {
                                                return
                                            }

                                            dragCoordinate = coordinate
                                            hoveredWorkSiteId = nearestVisibleWorkSite(to: coordinate)?.id
                                        }
                                        .onEnded { value in
                                            guard let coordinate = proxy.convert(value.location, from: .local) else {
                                                return
                                            }

                                            store.placeEmployee(selectedEmployee.id, at: coordinate)
                                            dragCoordinate = nil
                                            hoveredWorkSiteId = nil
                                            store.relocation.employeeId = nil
                                        }
                                )
                        }
                    }
                }

                VStack(spacing: 10) {
                    MapStat(label: "Obras", value: "\(visibleWorkSites.count)")
                    MapStat(label: "Operarios", value: "\(displayedEmployees.count)")
                }
                .padding(16)

                if let relocatingEmployee = selectedEmployeeForPlacement {
                    PlacementHint(
                        employee: relocatingEmployee,
                        hoveredWorkSite: hoveredWorkSite
                    )
                        .padding(.leading, 16)
                        .padding(.bottom, 24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            }
        }
    }

    private var visibleWorkSites: [WorkSite] {
        store.workSites.filter { $0.isActive && store.dailyState.visibleWorkSiteIds.contains($0.id) }
    }

    private var displayedEmployees: [Employee] {
        store.activeEmployees.filter { !store.isEmployeeAbsent($0.id) }
    }

    private var selectedEmployeeForPlacement: Employee? {
        guard let id = store.relocation.employeeId else { return nil }
        return displayedEmployees.first(where: { $0.id == id })
    }

    private func assignedCount(for workSiteId: String) -> Int {
        store.dailyState.employeePlacements.values.filter { $0.workSiteId == workSiteId }.count
    }

    private func placementFor(_ employeeId: String) -> EmployeePlacement? {
        store.dailyState.employeePlacements[employeeId]
    }

    private func shouldRenderEmployeeOnMap(_ employeeId: String) -> Bool {
        guard let relocatingId = store.relocation.employeeId else {
            return true
        }

        return employeeId != relocatingId || dragCoordinate == nil
    }

    private var hoveredWorkSite: WorkSite? {
        guard let hoveredWorkSiteId else { return nil }
        return visibleWorkSites.first(where: { $0.id == hoveredWorkSiteId })
    }

    private func nearestVisibleWorkSite(to coordinate: CLLocationCoordinate2D) -> WorkSite? {
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        return visibleWorkSites
            .map { workSite in
                let destination = CLLocation(latitude: workSite.lat, longitude: workSite.lng)
                return (workSite, origin.distance(from: destination))
            }
            .filter { $0.1 <= 30_000 }
            .sorted { $0.1 < $1.1 }
            .first?
            .0
    }
}

private struct WorkSiteBadge: View {
    let workSite: WorkSite
    let assignedCount: Int
    let highlighted: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(workSite.city)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.black)

            if assignedCount > 0 {
                Text("x\(assignedCount)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.82), in: Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(highlighted ? Color.ctrlAccent : Color.orange, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(highlighted ? 0.9 : 0), lineWidth: 2)
        )
        .scaleEffect(highlighted ? 1.06 : 1.0)
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
    }
}

private struct EmployeeOverlayBadge: View {
    let employee: Employee
    let selected: Bool
    let compact: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.03, green: 0.08, blue: 0.12))
                .frame(width: compact ? 24 : 42, height: compact ? 24 : 42)
                .overlay(
                    Circle()
                        .stroke(employee.color, lineWidth: selected ? 4 : 3)
                )

            if !compact {
                Text(employee.name.prefix(2).uppercased())
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .scaleEffect(selected ? 1.1 : 1.0)
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
    }
}

private struct PlacementHint: View {
    let employee: Employee
    let hoveredWorkSite: WorkSite?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.draw.fill")
                .foregroundStyle(Color.ctrlAccent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Colocando \(employee.name)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(hoveredWorkSite.map { "Suelta para asignar a \($0.city)" } ?? "Arrastra por el mapa y suelta para fijar la posición")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.75))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct MapStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.72))
        }
        .frame(width: 120, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
