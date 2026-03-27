import Foundation

extension Calendar {
    static let ctrl: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "es_ES")
        calendar.firstWeekday = 2
        return calendar
    }()

    var veryShortWeekdaySymbolsShifted: [String] {
        let symbols = veryShortStandaloneWeekdaySymbols
        let mondayIndex = 1
        return Array(symbols[mondayIndex...]) + Array(symbols[..<mondayIndex])
    }

    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? date
    }

    func startOfWeek(for date: Date) -> Date {
        dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    func gridDays(for month: Date) -> [Date] {
        guard
            let interval = dateInterval(of: .month, for: month),
            let firstWeek = dateInterval(of: .weekOfMonth, for: interval.start),
            let lastWeekReference = date(byAdding: .day, value: -1, to: interval.end),
            let lastWeek = dateInterval(of: .weekOfMonth, for: lastWeekReference)
        else {
            return []
        }

        var days: [Date] = []
        var cursor = firstWeek.start

        while cursor < lastWeek.end {
            days.append(cursor)
            guard let next = date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }

        return days
    }
}

extension Date {
    var ctrlKey: String {
        Self.ctrlKeyFormatter.string(from: self)
    }

    init?(ctrlKey: String) {
        guard let date = Self.ctrlKeyFormatter.date(from: ctrlKey) else {
            return nil
        }

        self = date
    }

    var longSpanishTitle: String {
        formatted(.dateTime.locale(Locale(identifier: "es_ES")).weekday(.wide).day().month(.wide).year())
            .capitalized
    }

    var monthTitleUppercased: String {
        formatted(.dateTime.locale(Locale(identifier: "es_ES")).month(.wide)).uppercased()
    }

    var dayNumberText: String {
        formatted(.dateTime.day())
    }

    func adding(days: Int) -> Date {
        Calendar.ctrl.date(byAdding: .day, value: days, to: self) ?? self
    }

    private static let ctrlKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
