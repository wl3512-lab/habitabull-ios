//
// the one thing her record can say back to her.
//
// A page of counts is a page of counts. The number that changes behaviour is
// the one that names a habit she already has: "you show up on Wednesdays" is
// a fact about her, and the only useful thing to do with it is to protect it.
//
// It is deliberately slow to speak. Two Wednesdays is a coincidence, and an
// app that calls it a pattern is the kind of app that tells you your one jog
// was a running streak. It stays quiet until the pattern is real.

import Foundation

public enum Insight {
    /// Days, not sessions: two workouts on one Wednesday is one Wednesday she
    /// turned up on. Showing up is the thing being counted.
    public static func daysByWeekday(_ sessions: [SessionRecord],
                                     zone: TimeZone = .current) -> [Int] {
        let cal = Attendance.calendar(zone)
        var counts = [Int](repeating: 0, count: 7)
        let days = Set(sessions.filter(\.attended).map(\.date))
        for day in days {
            guard let date = Attendance.date(day, cal) else { continue }
            // Calendar numbers Sunday 1, the app numbers it 0
            counts[cal.component(.weekday, from: date) - 1] += 1
        }
        return counts
    }

    /// The weekday she turns up on most, or nothing if it is too early to
    /// call it one. Six days of history and three of them on the same
    /// weekday: below that this is noise with a confident sentence over it.
    ///
    /// Ties go to the earlier weekday, which is arbitrary and has to be:
    /// the alternative is a headline that flips between two days every time
    /// the app redraws.
    public static func reliableWeekday(_ sessions: [SessionRecord],
                                       zone: TimeZone = .current) -> (weekday: Int, days: Int)? {
        let counts = daysByWeekday(sessions, zone: zone)
        let total = counts.reduce(0, +)
        guard total >= 6, let top = counts.max(), top >= 3,
              let weekday = counts.firstIndex(of: top) else { return nil }
        return (weekday, top)
    }
}

/// One day's heaviest finished set of one lift.
public struct LiftPoint: Sendable, Equatable {
    /// Local day, "2026-11-06".
    public var date: String
    public var weight: Double
    public var reps: Int

    public init(date: String, weight: Double, reps: Int) {
        self.date = date; self.weight = weight; self.reps = reps
    }
}

public enum Lifts {
    /// Her heaviest finished set of one lift per day she did it, oldest first.
    ///
    /// One point per day rather than per set, because the question a line
    /// answers is whether the lift is going up over weeks, and three working
    /// sets at the same weight are one answer to it, not three.
    ///
    /// Unfinished sessions count. A set she did and logged happened, whether
    /// or not she tapped the end of the workout, and dropping those days would
    /// put gaps in the line on exactly the days she was fighting for it.
    public static func track(_ sessions: [TrainingSession], _ exerciseId: String) -> [LiftPoint] {
        var best: [String: LiftPoint] = [:]
        for session in sessions {
            let sets = session.lifts
                .filter { $0.exerciseId == exerciseId }
                .flatMap(\.sets)
                .filter(\.done)
            guard let top = sets.max(by: ranks) else { continue }
            let point = LiftPoint(date: session.date, weight: top.weight, reps: top.reps)
            // two sessions on one day: the heavier of them is the day's set
            if let standing = best[session.date], !heavier(top, than: standing) { continue }
            best[session.date] = point
        }
        return best.values.sorted { $0.date < $1.date }
    }

    /// The lesser set, which is what `max` wants to be told: weight first,
    /// because that is the number the lift is named by, and at the same weight
    /// the set with more reps is the better one.
    private static func ranks(_ a: LoggedSet, below b: LoggedSet) -> Bool {
        a.weight == b.weight ? a.reps < b.reps : a.weight < b.weight
    }

    private static func heavier(_ a: LoggedSet, than b: LiftPoint) -> Bool {
        a.weight == b.weight ? a.reps > b.reps : a.weight > b.weight
    }
}
