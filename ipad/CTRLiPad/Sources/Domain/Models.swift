import CoreLocation
import Foundation
import SwiftUI

struct User: Identifiable, Codable, Hashable {
    let id: String
    var displayName: String
    var pin4: String
    var isActive: Bool
}

struct Employee: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var colorHex: String
    var isActive: Bool

    var color: Color {
        Color(hex: colorHex)
    }
}

struct WorkSite: Identifiable, Codable, Hashable {
    let id: String
    var internalCode: String
    var name: String
    var city: String
    var addressLine: String?
    var lat: Double
    var lng: Double
    var isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case internalCode
        case name
        case city
        case addressLine
        case lat
        case lng
        case isActive
    }

    init(
        id: String,
        internalCode: String,
        name: String,
        city: String,
        addressLine: String? = nil,
        lat: Double,
        lng: Double,
        isActive: Bool = true
    ) {
        self.id = id
        self.internalCode = internalCode
        self.name = name
        self.city = city
        self.addressLine = addressLine
        self.lat = lat
        self.lng = lng
        self.isActive = isActive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        internalCode = try container.decodeIfPresent(String.self, forKey: .internalCode) ?? WorkSite.makeFallbackInternalCode()
        name = try container.decode(String.self, forKey: .name)
        city = try container.decode(String.self, forKey: .city)
        addressLine = try container.decodeIfPresent(String.self, forKey: .addressLine)
        lat = try container.decode(Double.self, forKey: .lat)
        lng = try container.decode(Double.self, forKey: .lng)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
    }

    private static func makeFallbackInternalCode() -> String {
        String(Int.random(in: 10_000_000...99_999_999))
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

struct EmployeePlacement: Codable, Hashable {
    var employeeId: String
    var lat: Double
    var lng: Double
    var workSiteId: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

struct DailyState: Codable, Hashable {
    var date: String
    var notes: String
    var visibleWorkSiteIds: [String]
    var employeePlacements: [String: EmployeePlacement]
    var absentEmployeeIds: [String]

    enum CodingKeys: String, CodingKey {
        case date
        case notes
        case visibleWorkSiteIds
        case employeePlacements
        case absentEmployeeIds
    }

    init(
        date: String,
        notes: String,
        visibleWorkSiteIds: [String],
        employeePlacements: [String: EmployeePlacement],
        absentEmployeeIds: [String]
    ) {
        self.date = date
        self.notes = notes
        self.visibleWorkSiteIds = visibleWorkSiteIds
        self.employeePlacements = employeePlacements
        self.absentEmployeeIds = absentEmployeeIds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(String.self, forKey: .date)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        visibleWorkSiteIds = try container.decodeIfPresent([String].self, forKey: .visibleWorkSiteIds) ?? []
        employeePlacements = try container.decodeIfPresent([String: EmployeePlacement].self, forKey: .employeePlacements) ?? [:]
        absentEmployeeIds = try container.decodeIfPresent([String].self, forKey: .absentEmployeeIds) ?? []
    }
}

enum RightPanel: String, Codable {
    case none
    case employees
    case workSites
}

enum ManagementSection: String, Codable, Hashable {
    case home
    case archive
    case history
}

struct RelocationState: Codable, Hashable {
    var employeeId: String?
}

struct DocumentFile: Identifiable, Codable, Hashable {
    let id: String
    var workSiteId: String
    var fileName: String
    var fileType: String
    var createdAt: Date
    var createdByUserId: String?
}

struct WorkSiteEvent: Identifiable, Codable, Hashable {
    let id: String
    var workSiteId: String
    var createdAt: Date
    var createdByUserId: String?
    var type: String
    var title: String
    var summary: String
}

struct DailyBoardSnapshot: Codable {
    var selectedDate: String
    var users: [User]
    var employees: [Employee]
    var workSites: [WorkSite]
    var dailyStates: [String: DailyState]
    var documentFiles: [DocumentFile]
    var workSiteEvents: [WorkSiteEvent]

    enum CodingKeys: String, CodingKey {
        case selectedDate
        case users
        case employees
        case workSites
        case dailyStates
        case documentFiles
        case workSiteEvents
    }

    init(
        selectedDate: String,
        users: [User],
        employees: [Employee],
        workSites: [WorkSite],
        dailyStates: [String: DailyState],
        documentFiles: [DocumentFile],
        workSiteEvents: [WorkSiteEvent]
    ) {
        self.selectedDate = selectedDate
        self.users = users
        self.employees = employees
        self.workSites = workSites
        self.dailyStates = dailyStates
        self.documentFiles = documentFiles
        self.workSiteEvents = workSiteEvents
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedDate = try container.decode(String.self, forKey: .selectedDate)
        users = try container.decodeIfPresent([User].self, forKey: .users) ?? MockData.users
        employees = try container.decode([Employee].self, forKey: .employees)
        workSites = try container.decode([WorkSite].self, forKey: .workSites)
        dailyStates = try container.decode([String: DailyState].self, forKey: .dailyStates)
        documentFiles = try container.decodeIfPresent([DocumentFile].self, forKey: .documentFiles) ?? []
        workSiteEvents = try container.decodeIfPresent([WorkSiteEvent].self, forKey: .workSiteEvents) ?? []
    }
}

extension Color {
    init(hex: String) {
        let value = hex.replacingOccurrences(of: "#", with: "")
        var raw = UInt64()
        Scanner(string: value).scanHexInt64(&raw)

        let r = Double((raw >> 16) & 0xFF) / 255.0
        let g = Double((raw >> 8) & 0xFF) / 255.0
        let b = Double(raw & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
