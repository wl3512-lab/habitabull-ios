//
// When she trains, and what to call it.
//
// Ported from the web app's lib/schedule.ts. Two halves: deterministic rules
// for placing and spreading training days, and a parser that turns "free most
// evenings but Wednesdays are bad" into days without asking a model. The
// parser matters more than it looks — it is the offline fallback, and it is
// also what the model's answer is checked against, so anything outside these
// shapes is discarded.

import Foundation

public enum Anchor: String, Sendable, Codable, CaseIterable {
    case wake, lunch, afterwork, evening

    public var label: String {
        switch self {
        case .wake: "First thing"
        case .lunch: "Lunchtime"
        case .afterwork: "After work"
        case .evening: "Evening"
        }
    }

    public var hint: String {
        switch self {
        case .wake: "Before the day starts on you"
        case .lunch: "The middle of the day"
        case .afterwork: "On the way home, or just after"
        case .evening: "Once everything else is done"
        }
    }

    /// Minutes from midnight, for anything that needs one hour.
    public var minute: Int {
        switch self {
        case .wake: 7 * 60
        case .lunch: 12 * 60 + 30
        case .afterwork: 18 * 60
        case .evening: 20 * 60
        }
    }
}

public struct Availability: Sendable, Equatable {
    /// Days named outright. Empty means "no preference, you pick".
    public var days: [Int]
    /// Days named as bad. Removed from any plan.
    public var avoid: [Int]
    public var anchor: Anchor?
    /// Sessions per week, when a number was actually stated.
    public var count: Int?

    public init(days: [Int] = [], avoid: [Int] = [], anchor: Anchor? = nil, count: Int? = nil) {
        self.days = days; self.avoid = avoid; self.anchor = anchor; self.count = count
    }
}

public enum Schedule {
    static let fullDays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    /// Spread `count` sessions across the week with as much recovery between
    /// them as the week allows. Four sessions cannot all be non-consecutive in
    /// seven days; the standard answer is two pairs, not a run of four.
    ///
    /// With `today`, the pattern is rotated so the first session is today:
    /// signing up on a Thursday and being told "rest day" is a poor first
    /// sentence to somebody who came to lift, and every rotation keeps the
    /// shape that matters.
    public static func placeDays(_ count: Int, today: Int? = nil) -> [Int] {
        let n = min(7, max(1, count))
        let layouts: [Int: [Int]] = [
            1: [3], 2: [1, 4], 3: [1, 3, 5], 4: [1, 2, 4, 5],
            5: [1, 2, 3, 5, 6], 6: [1, 2, 3, 4, 5, 6], 7: [0, 1, 2, 3, 4, 5, 6],
        ]
        let base = layouts[n]!
        guard let today else { return base }
        let shift = (((today - base[0]) % 7) + 7) % 7
        return base.map { ($0 + shift) % 7 }.sorted()
    }

    /// True when two chosen days sit next to each other, wrapping the week.
    public static func hasBackToBack(_ days: [Int]) -> Bool {
        let set = Set(days)
        return days.contains { set.contains(($0 + 1) % 7) }
    }

    /// Pick `count` days from what is available, as far apart as the list
    /// allows. Evenly spaced rather than the first N: somebody free every
    /// evening who trains three times should get Sunday, Tuesday, Friday.
    public static func spread(_ available: [Int], count: Int) -> [Int] {
        let days = Array(Set(available)).sorted()
        if days.count <= count { return days }
        let step = Double(days.count) / Double(count)
        return (0..<count).map { days[Int((Double($0) * step).rounded(.down))] }
    }

    /// Turn what somebody said into an actual week.
    ///
    /// The distinction that matters: `days` is when she is *available*, not how
    /// often she wants to train. "Free most evenings" lists six days and says
    /// nothing about frequency, so the count comes from what she asked for or
    /// from the guidance default, never from the length of the list.
    public static func planWeek(_ a: Availability, fallbackCount: Int = 3) -> [Int] {
        let count = min(7, max(1, a.count ?? fallbackCount))
        let available = a.days.filter { !a.avoid.contains($0) }
        if available.count >= count { return spread(available, count: count) }

        var chosen = available
        for d in placeDays(count) where !a.avoid.contains(d) && !chosen.contains(d) {
            if chosen.count >= count { break }
            chosen.append(d)
        }
        // Still short because too much was ruled out: take whatever is left.
        var d = 1
        while d <= 7 && chosen.count < count {
            let day = d % 7
            if !a.avoid.contains(day) && !chosen.contains(day) { chosen.append(day) }
            d += 1
        }
        return chosen.sorted()
    }

    /// Which part of the day an hour belongs to. Evening wraps past midnight.
    public static func anchorForHour(_ hour: Int) -> Anchor {
        if hour >= 5 && hour <= 10 { return .wake }
        if hour >= 11 && hour <= 14 { return .lunch }
        if hour >= 15 && hour <= 19 { return .afterwork }
        return .evening
    }

    /// The earliest of the chosen slots.
    public static func primaryAnchor(_ anchors: [Anchor]?) -> Anchor? {
        guard let anchors, !anchors.isEmpty else { return nil }
        return anchors.sorted { $0.minute < $1.minute }.first
    }

    /// "after work", "mornings or evenings", "whenever you can".
    public static func anchorLabel(_ anchors: [Anchor]?) -> String? {
        guard let anchors else { return nil }
        if anchors.isEmpty { return "whenever you can" }
        let names = anchors.sorted { $0.minute < $1.minute }.map { $0.label.lowercased() }
        if names.count == 1 { return names[0] }
        return names.dropLast().joined(separator: ", ") + " or " + names[names.count - 1]
    }

    /// The next day she said she would train, named rather than counted:
    /// "in 2 days" is arithmetic she has to do, "Thursday" is not.
    public static func nextTrainingDay(_ days: [Int]?, todayWeekday dow: Int) -> String? {
        guard let days, !days.isEmpty else { return nil }
        for i in 1...7 {
            let d = (dow + i) % 7
            if days.contains(d) { return i == 1 ? "tomorrow" : fullDays[d] }
        }
        return nil
    }

    /// When she actually trains, as opposed to when she said she would.
    ///
    /// Deliberately conservative: a real sample and a clear majority before it
    /// says anything, because being told "you are a morning person now" off two
    /// sessions is worse than silence.
    public static func observedAnchor(
        completedHours hours: [Int],
        minSessions: Int = 5,
        majority: Double = 0.5
    ) -> (anchor: Anchor, count: Int, total: Int)? {
        if hours.count < minSessions { return nil }
        var tally: [Anchor: Int] = [:]
        for h in hours { tally[anchorForHour(h), default: 0] += 1 }
        // Ties go to the earlier slot, so the answer does not depend on the
        // order a dictionary happens to hand back.
        guard let best = tally.sorted(by: { a, b in
            a.value != b.value ? a.value > b.value : a.key.minute < b.key.minute
        }).first else { return nil }
        if Double(best.value) / Double(hours.count) < majority { return nil }
        return (best.key, best.value, hours.count)
    }
}
