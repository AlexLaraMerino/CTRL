import Foundation

enum MockData {
    static let users: [User] = [
        User(id: "user-3021", displayName: "3021", pin4: "3021", isActive: true),
        User(id: "user-3016", displayName: "3016", pin4: "3016", isActive: true),
        User(id: "user-3004", displayName: "3004", pin4: "3004", isActive: true)
    ]

    static let employees: [Employee] = [
        Employee(id: "emp-javier", name: "Javier", colorHex: "#22C55E", isActive: true),
        Employee(id: "emp-lucia", name: "Lucia", colorHex: "#84CC16", isActive: true),
        Employee(id: "emp-marcos", name: "Marcos", colorHex: "#38BDF8", isActive: true),
        Employee(id: "emp-julio", name: "Julio", colorHex: "#F97316", isActive: true),
        Employee(id: "emp-cora", name: "Cora", colorHex: "#14B8A6", isActive: true)
    ]

    static let workSites: [WorkSite] = [
        WorkSite(id: "ws-malaga", internalCode: "43158207", name: "Residencial Sur", city: "Malaga", lat: 36.7213, lng: -4.4214),
        WorkSite(id: "ws-madrid", internalCode: "58293416", name: "Torre Norte", city: "Madrid", lat: 40.4168, lng: -3.7038),
        WorkSite(id: "ws-bilbao", internalCode: "70824651", name: "Cubierta Este", city: "Bilbao", lat: 43.2630, lng: -2.9350),
        WorkSite(id: "ws-zaragoza", internalCode: "81420579", name: "Hospital Técnico", city: "Zaragoza", lat: 41.6488, lng: -0.8891),
        WorkSite(id: "ws-valencia", internalCode: "92547163", name: "Edificio Delta", city: "Valencia", lat: 39.4699, lng: -0.3763)
    ]

    static func seedDailyState(for date: Date, employees: [Employee], workSites: [WorkSite]) -> DailyState {
        var placements: [String: EmployeePlacement] = [:]

        for (index, employee) in employees.enumerated() {
            let workSite = workSites[index % workSites.count]
            placements[employee.id] = EmployeePlacement(
                employeeId: employee.id,
                lat: workSite.lat,
                lng: workSite.lng,
                workSiteId: workSite.id
            )
        }

        return DailyState(
            date: date.ctrlKey,
            notes: "",
            visibleWorkSiteIds: workSites.filter(\.isActive).map(\.id),
            employeePlacements: placements,
            absentEmployeeIds: []
        )
    }
}
