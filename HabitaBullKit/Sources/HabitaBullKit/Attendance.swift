//
// Whether she went, and the week and month views built on that one answer.
//
// Ported from the web app's lib/attendance.ts, lib/calendar.ts and
// streakWeeks in lib/engine.ts.
//
// The rule underneath all of it: a logged set is proof she turned up, finished
// or not. The web version used to ask for `completedAt`, which only the Finish
// button writes, and Finish only appears after the last set of the last lift.
// End, where most sessions actually stop, keeps every set — and the day went
// missing from the calendar, the streak and the month count alike. "Only two
// sessions are saved even though I logged way more" was the app telling her she
// had not been to the gym on days she had.
//
// A session she opened and logged nothing in is not a gym visit.

import Foundation

/// A session as the calendar needs it: when, and whether it counts.
public struct SessionRecord: Sendable, Equatable {
    /// Local day, "2026-11-06". Never UTC: an 11pm workout belongs to today.
    public var date: String
    /// She pressed Finish.
    public var completed: Bool
    /// At least one set was logged.
    public var loggedSet: Bool

    public init(date: String, completed: Bool, loggedSet: Bool) {
        self.date = date; self.completed = completed; self.loggedSet = loggedSet
    }

    public var attended: Bool { completed || loggedSet }
}

/// One day of the week strip, as the week actually stands.
public struct StripDay: Sendable, Equatable {
    /// Sunday-indexed, matching the calendar and the chosen training days.
    public var index: Int
    /// The single letter under the dot.
    public var initial: String
    public var date: String
    public var trained: Bool
    public var isToday: Bool
    public var planned: Bool
    /// A gym day still ahead of her this week.
    public var upcoming: Bool
}

/// One cell of a month grid. A padding cell has no date.
public struct MonthCell: Sendable, Equatable {
    public var date: String?
    public var day: Int?
    public var trained: Bool
    /// First session back after a gap of a week or more.
    public var comeback: Bool
    public var isToday: Bool
    public var future: Bool
    public var hasPhoto: Bool
}

public enum Attendance {
    static let initials = ["S", "M", "T", "W", "T", "F", "S"]

    /// All date maths is done in one calendar, handed in so a test can pin it.
    /// Everything is local-time by design.
    public static func calendar(_ zone: TimeZone = .current) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = zone
        return c
    }

    public static func day(_ date: Date, _ cal: Calendar) -> String {
        let p = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", p.year ?? 0, p.month ?? 0, p.day ?? 0)
    }

    public static func date(_ day: String, _ cal: Calendar) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// The days the crew is told she trained.
    ///
    /// Every day she went, with one hold: today's session until she finishes
    /// it. End leaves a session open to carry on, so on the day itself there is
    /// no telling a session she stopped from one she is still in, and a workout
    /// in progress is nobody's business but hers.
    public static func checkinDates(_ sessions: [SessionRecord], today: String) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for s in sessions where s.completed || (s.date < today && s.attended) {
            if seen.insert(s.date).inserted { out.append(s.date) }
        }
        return out
    }

    /// The current week, Sunday first.
    public static func weekStrip(
        _ sessions: [SessionRecord], trainingDays: [Int], today: String, zone: TimeZone = .current
    ) -> [StripDay] {
        let cal = calendar(zone)
        guard let now = date(today, cal) else { return [] }
        let trained = Set(sessions.filter(\.attended).map(\.date))
        let weekday = cal.component(.weekday, from: now) - 1   // 0 = Sunday
        guard let start = cal.date(byAdding: .day, value: -weekday, to: now) else { return [] }

        return initials.enumerated().map { index, initial in
            let d = cal.date(byAdding: .day, value: index, to: start)!
            let key = day(d, cal)
            return StripDay(
                index: index, initial: initial, date: key,
                trained: trained.contains(key),
                isToday: key == today,
                planned: trainingDays.contains(index),
                // A planned day already past stays quiet: absence, not failure.
                upcoming: key > today
            )
        }
    }

    /// Dates that were the first session back after a break.
    public static func comebackDates(_ sessions: [SessionRecord], gapDays: Int = 7, zone: TimeZone = .current) -> Set<String> {
        let cal = calendar(zone)
        let days = sessions.filter(\.attended).map(\.date).sorted()
        var out = Set<String>()
        for i in 1..<max(1, days.count) {
            guard let a = date(days[i - 1], cal), let b = date(days[i], cal) else { continue }
            let gap = Int((b.timeIntervalSince(a) / 86_400).rounded())
            if gap >= gapDays { out.insert(days[i]) }
        }
        return out
    }

    /// The biggest break she has actually come back from. Zero if she never has.
    public static func longestComebackGap(_ sessions: [SessionRecord], zone: TimeZone = .current) -> Int {
        let cal = calendar(zone)
        let days = sessions.filter(\.attended).map(\.date).sorted()
        var longest = 0
        for i in 1..<max(1, days.count) {
            guard let a = date(days[i - 1], cal), let b = date(days[i], cal) else { continue }
            let gap = Int((b.timeIntervalSince(a) / 86_400).rounded())
            if gap >= 7 { longest = max(longest, gap) }
        }
        return longest
    }

    /// A month as calendar rows, Sunday-first, padded to whole weeks so the
    /// grid stays rectangular. `month` is 1-12.
    public static func monthMatrix(
        year: Int, month: Int, sessions: [SessionRecord],
        photoDates: [String] = [], today: String, zone: TimeZone = .current
    ) -> [[MonthCell]] {
        // 1-12, unlike the web's 0-11. Rolling over would quietly return a
        // different month: month 0 is December of the year before.
        guard (1...12).contains(month) else { return [] }
        let cal = calendar(zone)
        let trained = Set(sessions.filter(\.attended).map(\.date))
        let comebacks = comebackDates(sessions, zone: zone)
        let photos = Set(photoDates)

        guard let first = cal.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = cal.range(of: .day, in: .month, for: first) else { return [] }
        let daysInMonth = range.count
        let lead = cal.component(.weekday, from: first) - 1
        let total = Int(ceil(Double(lead + daysInMonth) / 7)) * 7

        var cells: [MonthCell] = []
        for i in 0..<total {
            let dayNum = i - lead + 1
            guard dayNum >= 1, dayNum <= daysInMonth,
                  let d = cal.date(from: DateComponents(year: year, month: month, day: dayNum)) else {
                cells.append(MonthCell(date: nil, day: nil, trained: false, comeback: false,
                                       isToday: false, future: false, hasPhoto: false))
                continue
            }
            let key = day(d, cal)
            cells.append(MonthCell(date: key, day: dayNum, trained: trained.contains(key),
                                   comeback: comebacks.contains(key), isToday: key == today,
                                   future: key > today, hasPhoto: photos.contains(key)))
        }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<min($0 + 7, cells.count)]) }
    }

    /// Days she went in a given month. `month` is 1-12.
    public static func sessionsInMonth(_ sessions: [SessionRecord], year: Int, month: Int) -> Int {
        let prefix = String(format: "%04d-%02d", year, month)
        return sessions.filter { $0.attended && $0.date.hasPrefix(prefix) }.count
    }

    /// Twelve counts, January to December.
    public static func yearCounts(_ sessions: [SessionRecord], year: Int) -> [Int] {
        (1...12).map { sessionsInMonth(sessions, year: year, month: $0) }
    }

    /// Weeks in a row with at least one session in them, counting back from
    /// this week. Counted in weeks, not days, so a four-day lifter never sees
    /// a broken streak for resting on Tuesday. This week not having happened
    /// yet does not break it.
    public static func streakWeeks(_ sessions: [SessionRecord], today: String, zone: TimeZone = .current) -> Int {
        let cal = calendar(zone)
        let attendedDays = sessions.filter(\.attended).map(\.date)
        if attendedDays.isEmpty { return 0 }
        guard let now = date(today, cal) else { return 0 }

        func weekOf(_ d: Date) -> String {
            let weekday = cal.component(.weekday, from: d) - 1
            return day(cal.date(byAdding: .day, value: -weekday, to: d)!, cal)
        }

        let weeks = Set(attendedDays.compactMap { date($0, cal).map(weekOf) })
        let thisWeek = weekOf(now)
        var streak = 0
        var cursor = now
        while true {
            let week = weekOf(cursor)
            if weeks.contains(week) { streak += 1 }
            else if streak > 0 || week != thisWeek { break }
            cursor = cal.date(byAdding: .day, value: -7, to: cursor)!
            if streak > 520 { break }
        }
        return streak
    }
}
