//
// one lift, one number, one date.
//
// The rule that matters is how far along it reads, and it is measured from
// where she started rather than from zero: setting a 200 lb deadlift goal
// while already pulling 150 should not open at 75% done. It should open at 0%
// of the distance she set out to cover, because that distance is the goal.

import Foundation

public struct Goal: Sendable, Equatable, Codable {
    public var exerciseId: String
    public var targetWeight: Double
    /// Local day, "2026-12-10".
    public var targetDate: String
    /// What she was lifting the day she set it.
    ///
    /// Written down rather than worked out again later, because "where she
    /// started" means where she started *this goal*. Reading it off the
    /// oldest session in her history is a different question, and it answers
    /// wrong for anyone who has been training a while: somebody who opened at
    /// 100 lb, is at 150 now and sets a 200 lb goal would see it open at 50%
    /// done, which is a goal that congratulates her for the past.
    ///
    /// Optional because goals saved before this existed have no baseline,
    /// and those fall back to the old reading rather than to zero.
    public var startWeight: Double?

    public init(exerciseId: String, targetWeight: Double, targetDate: String,
                startWeight: Double? = nil) {
        self.exerciseId = exerciseId
        self.targetWeight = targetWeight
        self.targetDate = targetDate
        self.startWeight = startWeight
    }
}

public enum Goals {
    /// The heaviest set of that lift she has actually finished. A set left
    /// undone is a set she did not lift.
    public static func best(_ sessions: [TrainingSession], _ exerciseId: String) -> Double {
        sessions.flatMap(\.lifts)
            .filter { $0.exerciseId == exerciseId }
            .flatMap(\.sets)
            .filter(\.done)
            .map(\.weight)
            .max() ?? 0
    }

    /// Where she was when she started: the heaviest set of that lift in the
    /// oldest session that has one.
    ///
    /// Read off the earliest date rather than the end of the array, because
    /// the app appends and the package is handed whatever order the caller
    /// has, and an order assumption here would quietly rebase every goal.
    public static func start(_ sessions: [TrainingSession], _ exerciseId: String) -> Double {
        let withLift = sessions.filter { session in
            session.lifts.contains { lift in
                lift.exerciseId == exerciseId && lift.sets.contains(where: \.done)
            }
        }
        guard let first = withLift.min(by: { $0.date < $1.date }) else { return 0 }
        return best([first], exerciseId)
    }

    /// Where this goal started from: what she was lifting when she set it,
    /// or, for a goal saved before that was written down, the oldest session
    /// in her history.
    public static func baseline(_ sessions: [TrainingSession], _ goal: Goal) -> Double {
        goal.startWeight ?? start(sessions, goal.exerciseId)
    }

    /// 0 to 100, as a whole number, because a bar and a percentage are both
    /// read at a glance and neither is improved by a decimal.
    public static func progress(_ sessions: [TrainingSession], _ goal: Goal) -> Int {
        let best = best(sessions, goal.exerciseId)
        let start = baseline(sessions, goal)
        // a goal at or below where she started is either already met or it is
        // not a distance at all, and dividing by it would be nonsense
        guard goal.targetWeight > start else { return best >= goal.targetWeight ? 100 : 0 }
        let share = (best - start) / (goal.targetWeight - start) * 100
        return min(100, max(0, Int(share.rounded())))
    }

    public static func met(_ sessions: [TrainingSession], _ goal: Goal) -> Bool {
        best(sessions, goal.exerciseId) >= goal.targetWeight
    }

    /// Whole days from today to the date she picked. Negative once it is past,
    /// which is a thing the screen has to be able to say rather than hide.
    public static func daysLeft(_ goal: Goal, from today: Date = .now,
                                _ cal: Calendar = Attendance.calendar()) -> Int? {
        guard let target = Attendance.date(goal.targetDate, cal) else { return nil }
        let start = cal.startOfDay(for: today)
        return cal.dateComponents([.day], from: start, to: cal.startOfDay(for: target)).day
    }
}
