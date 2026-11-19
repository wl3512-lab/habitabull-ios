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
    /// Her best finished set of one lift per day she did it, oldest first.
    ///
    /// One point per day rather than per set, because the question a line
    /// answers is whether the lift is going up over weeks, and three working
    /// sets at the same weight are one answer to it, not three.
    ///
    /// Unfinished sessions count. A set she did and logged happened, whether
    /// or not she tapped the end of the workout, and dropping those days would
    /// put gaps in the line on exactly the days she was fighting for it.
    ///
    /// - Parameter assisted: whether the number on this lift is help rather
    ///   than load. On an assisted machine the best set of a day is the one
    ///   she needed the least help on, so "best" runs the other way, and the
    ///   line it draws falls as she gets stronger. Left out, bigger is
    ///   better, which is every other lift.
    public static func track(_ sessions: [TrainingSession], _ exerciseId: String,
                             assisted: Bool = false) -> [LiftPoint] {
        var best: [String: LiftPoint] = [:]
        for session in sessions {
            let sets = session.lifts
                .filter { $0.exerciseId == exerciseId }
                .flatMap(\.sets)
                .filter(\.done)
            guard let top = sets.max(by: { ranks($0, below: $1, assisted) }) else { continue }
            let point = LiftPoint(date: session.date, weight: top.weight, reps: top.reps)
            // two sessions on one day: the better of them is the day's set
            if let standing = best[session.date],
               !better(top, than: standing, assisted) { continue }
            best[session.date] = point
        }
        return best.values.sorted { $0.date < $1.date }
    }

    /// Whether a line is drawn in reps rather than in pounds.
    ///
    /// A lift with no load on it is not a flat line at zero, it is a line
    /// drawn in reps: chin-ups and push-ups get better by the rep, and a
    /// line that cannot say so says nothing is happening.
    ///
    /// An assisted machine is never read that way. A history that is all
    /// zeroes there means she needs no help at all, which is the top of the
    /// lift rather than the absence of a number. The chart decided this for
    /// itself and the card beside it decided again, so a lift she now does
    /// unaided drew a line in reps under a figure reading "0 lb", and the
    /// first day she went back to a little help switched the chart's units
    /// without saying so. One rule, in one place, so they cannot disagree.
    /// Found by a codex audit 2026-11-17.
    public static func countedInReps(_ points: [LiftPoint], assisted: Bool) -> Bool {
        !assisted && points.allSatisfy { $0.weight == 0 }
    }

    /// Where she is now, in this lift's own units.
    ///
    /// This was a private function on the Progress screen and it asked a
    /// different question from the chart beside it: whether the LAST point
    /// carried a weight. So a loaded lift whose most recent day happened to
    /// be at zero printed its headline in reps under a line still drawn in
    /// pounds. Here, next to the rule, both ask the same thing.
    /// Found by a codex audit 2026-11-17.
    public static func headline(_ points: [LiftPoint], assisted: Bool) -> String {
        guard let last = points.last else { return "" }
        guard countedInReps(points, assisted: assisted) else {
            return "\(last.weight.formatted()) lb"
        }
        return "\(last.reps) \(last.reps == 1 ? "rep" : "reps")"
    }

    /// What she has added since the first day of it, and nothing at all when
    /// she has added nothing. "+0" reads as a result and it is not one, and a
    /// negative number here would be the app telling her off for a deload.
    ///
    /// Going down is going up on a machine that counts help, so 45 lb of it
    /// down to 40 was hidden as a loss and 40 back up to 45 was printed as a
    /// green "+5".
    public static func gain(_ points: [LiftPoint], assisted: Bool) -> String? {
        guard let first = points.first, let last = points.last, points.count > 1 else { return nil }
        let byReps = countedInReps(points, assisted: assisted)
        let up = byReps
            ? Double(last.reps - first.reps)
            : (assisted ? first.weight - last.weight : last.weight - first.weight)
        guard up > 0 else { return nil }
        return "+\(up.formatted())"
    }

    /// Which of two sets is the better one: weight first, because that is the
    /// number the lift is named by, and at the same weight the one with more
    /// reps. On a machine that counts help, less of it is better, so the
    /// weight comparison turns around; the reps do not.
    ///
    /// Public because the day card asked the same question with its own copy
    /// of half the answer: it compared weight only, so at 135 for 5 and 135
    /// for 8 the card named one set and the chart named the other.
    /// Found by a codex audit 2026-11-17.
    public static func beats(_ a: (weight: Double, reps: Int),
                             _ b: (weight: Double, reps: Int), assisted: Bool) -> Bool {
        if a.weight == b.weight { return a.reps > b.reps }
        return assisted ? a.weight < b.weight : a.weight > b.weight
    }

    /// The lesser set, which is what `max` wants to be told: weight first,
    /// because that is the number the lift is named by, and at the same weight
    /// the set with more reps is the better one.
    ///
    /// On a machine that counts help, less of it is the better set, so the
    /// weight comparison turns around. The reps do not: more reps is more
    /// reps whichever way the weight reads.
    private static func ranks(_ a: LoggedSet, below b: LoggedSet, _ assisted: Bool) -> Bool {
        beats((b.weight, b.reps), (a.weight, a.reps), assisted: assisted)
    }

    private static func better(_ a: LoggedSet, than b: LiftPoint, _ assisted: Bool) -> Bool {
        beats((a.weight, a.reps), (b.weight, b.reps), assisted: assisted)
    }
}
