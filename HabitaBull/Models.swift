//
// what a workout looks like as data. the names match the web app's lib/types.ts,
// so a backup from the web version can be read here later

import Foundation

struct LoggedSet: Codable, Equatable {
    var weight: Double
    var reps: Int
    var done = false
}

struct LoggedExercise: Codable, Equatable {
    var exerciseId: String
    var sets: [LoggedSet]

    var setsLeft: Int { sets.filter { !$0.done }.count }

    var canDropSet: Bool { sets.count > 1 && sets.last?.done == false }

    // the library's name, or the one you gave a lift of your own
    var name: String {
        ExerciseLibrary.find(exerciseId)?.name
            ?? exerciseId.replacingOccurrences(of: "custom-", with: "")
                .replacingOccurrences(of: "-", with: " ").capitalized
    }

    // lifts of your own go up in 5s
    var weightStep: Double { ExerciseLibrary.find(exerciseId)?.increment ?? 5 }
    var usesWeight: Bool { weightStep > 0 }
    var isBarbell: Bool { ExerciseLibrary.find(exerciseId)?.equipment == "barbell" }

    /// What the second number on a set actually counts.
    ///
    /// One field does three jobs: a squat is counted in repetitions, a plank
    /// in seconds, a treadmill in minutes. That is a property of the lift and
    /// not of the muscle — a machine crunch is reps, a plank is not — so the
    /// library's hold and cardio flags decide it, and every screen asks here
    /// rather than each one guessing. Guessing is how a plank came to be
    /// planned for twelve of something nobody could name.
    enum Counted { case reps, seconds, minutes }

    var counted: Counted {
        guard let lift = ExerciseLibrary.find(exerciseId) else { return .reps }
        if lift.cardio { return .minutes }
        return lift.hold ? .seconds : .reps
    }

    var isHold: Bool { counted == .seconds }

    /// How it reads beside a number: "8 reps", "30 sec", "20 min".
    var unit: String {
        switch counted {
        case .reps: return "reps"
        case .seconds: return "sec"
        case .minutes: return "min"
        }
    }

    /// What the stepper above it is called.
    var countLabel: String {
        switch counted {
        case .reps: return "Reps"
        case .seconds: return "Seconds"
        case .minutes: return "Minutes"
        }
    }

    /// Reps move one at a time, because six pull-ups is a number people have.
    /// Seconds and minutes move in fives: nobody holds a plank for 31.
    var countStep: Double { counted == .reps ? 1 : 5 }

    /// The limits belong to the unit too. One rep is a set; one second is a
    /// flinch, and a minus from 30 seconds has to land back on a number the
    /// plus can reach, so the floor is a multiple of the step.
    var countRange: ClosedRange<Double> {
        switch counted {
        case .reps: return 1...200
        case .seconds: return 5...600      // ten minutes, enough for any hold
        case .minutes: return 5...240
        }
    }

    /// Spoken aloud, where "sec" and "x" do not read well.
    var spokenUnit: String {
        switch counted {
        case .reps: return "reps"
        case .seconds: return "seconds"
        case .minutes: return "minutes"
        }
    }

    func spoken(_ set: LoggedSet) -> String {
        if usesWeight { return "\(set.weight.formatted()) pounds for \(set.reps) \(spokenUnit)" }
        return "\(set.reps) \(spokenUnit)"
    }

    /// How the day reads on Today: "3 x 8" for reps, which needs no unit, and
    /// "1 x 30 sec" for the ones that do. A number with no unit beside it is
    /// how a plank came to be planned for twelve of nothing.
    var planLine: String {
        let count = sets.count
        let first = sets.first?.reps ?? 0
        return counted == .reps ? "\(count) × \(first)" : "\(count) × \(first) \(unit)"
    }

    // one set, said the way the screens say it
    func describe(_ set: LoggedSet) -> String {
        if usesWeight { return "\(set.weight.formatted()) lb × \(set.reps)" }
        return "\(set.reps) \(unit)"
    }
}

struct Session: Codable, Equatable, Identifiable {
    var id: String
    var date: String        // local day, "2026-11-05"
    var label: String
    var exercises: [LoggedExercise]
    var startedAt: Date
    var completedAt: Date? = nil

    // where you were, so closing the app costs nothing. both are empty on older saves
    var chosenLift: Int? = nil
    var restEndsAt: Date? = nil
    var restLift: Int? = nil

    var setsDone: Int {
        exercises.reduce(0) { $0 + $1.sets.filter(\.done).count }
    }

    // lifts with at least one logged set
    var liftsDone: Int {
        exercises.filter { $0.sets.contains(where: \.done) }.count
    }

    // weight × reps across every logged set
    var poundsMoved: Int {
        Int(exercises.flatMap(\.sets).filter(\.done).reduce(0) { $0 + $1.weight * Double($1.reps) })
    }

    var setsTotal: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }

    // every lift with sets left, by where it sits in the workout. the screen
    // between lifts offers these, and the first of them is always what
    // nextSet would have opened on its own: same predicate, same order
    var liftsLeft: [Int] {
        exercises.indices.filter { exercises[$0].setsLeft > 0 }
    }

    // the next set to do, as two positions: which lift, then which set of it.
    // nil means every set is logged
    var nextSet: (exercise: Int, set: Int)? {
        for (e, exercise) in exercises.enumerated() {
            if let s = exercise.sets.firstIndex(where: { !$0.done }) {
                return (e, s)
            }
        }
        return nil
    }
}

// what logging a set meant, so the screen can answer it
struct SetOutcome: Equatable {
    enum Kind { case routine, first, best }

    var kind: Kind
    var liftName: String
    var resting: Bool       // false when that was the last set of the workout
    var newBest: Double? = nil      // only on a new best
    var gain: Double? = nil         // how far past the old best
}

// a lift that beat your old heaviest
struct SessionBest: Equatable {
    var liftName: String
    var was: Double
    var now: Double

    var gain: Double { now - was }
}

// one fixed workout for now, so the loop can be tried before the planner
// exists. names only: the weight, the reps and the number of sets all come
// from the rules, and a hand-written 95 lb squat sitting here was two answers
// to one question with no way to tell which one you were reading
let starterLifts = ["back-squat", "leg-press"]

// "Cable Crossover" -> "custom-cable-crossover"
func customLiftId(_ name: String) -> String {
    let words = name.lowercased().split { !$0.isLetter && !$0.isNumber }
    return "custom-" + words.joined(separator: "-")
}

// the local calendar day. never UTC: an 11pm workout belongs to today.
//
// Gregorian on purpose, in the local time zone, which is what the rules
// package counts attendance in. `Calendar.current` is the phone's calendar,
// and on a phone set to the Buddhist calendar it writes 2569-11-11 for a
// workout the week strip then looks for under 2026-11-11: every day she
// trained would read as a day she missed.
func dayString(_ date: Date = .now) -> String {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = .current
    let parts = cal.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
}
