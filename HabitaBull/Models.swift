//
// what a workout looks like as data. the names match the web app's lib/types.ts,
// so a backup from the web version can be read here later

import Foundation
// for the one rule about which of two sets is the better one. This module has
// a LoggedSet of its own and the package has another; where that matters the
// module is named, as it is in Progress.swift.
import HabitaBullKit

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
    var name: String { liftName(exerciseId) }

    /// Whether the number on this lift is help rather than load.
    ///
    /// Every screen that prints or ranks a weight has to know, and four of
    /// them were each deciding it for themselves or not at all. One place to
    /// ask, next to the other things the library answers.
    var assisted: Bool { ExerciseLibrary.find(exerciseId)?.assisted ?? false }

    /// The best of some of this lift's sets: the heaviest, or on a machine
    /// that counts help, the one she needed the least of it on. At the same
    /// weight it is the one with more reps, which is the chart's rule and was
    /// not this card's until a codex audit 2026-11-17 put them side by side.
    func best(of sets: [LoggedSet]) -> LoggedSet? {
        sets.max { Lifts.beats(($1.weight, $1.reps), ($0.weight, $0.reps), assisted: assisted) }
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

    /// How a planned lift reads before she starts it: "3 × 8 · 147.5 lb".
    ///
    /// The weight is the point of showing the plan at all. "3 × 8" is a
    /// shape. "3 × 8 · 147.5 lb" is a workout she can decide she is up for,
    /// and it is the one thing the web app's Today has always said and the
    /// phone's did not.
    var planDetail: String {
        guard usesWeight, let weight = sets.first?.weight else { return planLine }
        // No help is a plan, and `weight > 0` dropped it: a day the app had
        // decided she should try the lift unaided read as "3 × 8" with no
        // setting at all, which is the one session where the setting is the
        // whole point. On a bar zero really is nothing to say.
        // Found by a codex audit 2026-11-17.
        if assisted { return "\(planLine) · \(weight == 0 ? "no help" : "\(weight.formatted()) lb")" }
        guard weight > 0 else { return planLine }
        return "\(planLine) · \(weight.formatted()) lb"
    }

    /// Her record on this lift, said the way this lift reads, or nothing
    /// when there is no record worth printing.
    ///
    /// On a machine that counts help her record is the least of it she has
    /// ever needed, and the best of all is none. The log screen asked for
    /// `best > 0`, which hid the line on exactly the day it had the most to
    /// say: the first rep she did unaided turned "Best 2.5 lb" into no line
    /// at all. Zero is the top of an assisted lift, not the absence of a
    /// number. Found by a codex audit 2026-11-17.
    ///
    /// On a bar zero is still nothing to say, because a bodyweight lift
    /// carries no load and "Best 0 lb" is not a record.
    ///
    /// The words live here rather than in the screen so that a test can ask
    /// what they are.
    func bestSaid(_ best: Double?) -> String? {
        guard usesWeight, let best else { return nil }
        if assisted {
            return best == 0 ? "Best: no help" : "Best \(best.formatted()) lb of help"
        }
        return best > 0 ? "Best \(best.formatted()) lb" : nil
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

    /// weight × reps across every logged set.
    ///
    /// Assisted machines are left out of it. Their number is counterweight,
    /// so counting it made the total rise as she needed more help, and the
    /// day she finally did a pull-up with none of it that lift contributed
    /// nothing at all. There is no honest number without her bodyweight
    /// behind it, so the total says less rather than something backwards.
    /// The stat is already hidden when it comes to nothing, so a session of
    /// only assisted work shows no total instead of a wrong one.
    /// Found by a codex audit 2026-11-17.
    /// Not an `Int`: one set of 22.5 for three is 67.5 lb, and truncating it
    /// printed 67 on a number she can check on her fingers. `.formatted()`
    /// only shows a fraction when there is one, so a real session still reads
    /// as a round number. Found by a codex audit 2026-11-18.
    var poundsMoved: Double {
        let counted = exercises.filter { !$0.assisted }.flatMap(\.sets).filter(\.done)
        return counted.reduce(0) { $0 + $1.weight * Double($1.reps) }
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
    /// Whether that set was the last one of the session.
    ///
    /// Not the same question as `resting`, which is also false for a set she
    /// went back to fix, and for the one the screen stays on during a
    /// correction. This is only true for the set that finished the workout,
    /// so the beat can say so without saying it over a typo she came back to
    /// put right.
    var finishes = false
    var newBest: Double? = nil      // only on a new best
    var gain: Double? = nil         // how far past the old best
    /// Whether that number is help rather than load. The gain was already
    /// worked out in the right direction; the sentence printed beside it was
    /// not, so taking 5 lb less help was announced as "5 lb more than your
    /// best". Found by a codex audit 2026-11-17.
    var assisted = false
}

// a lift that beat your old heaviest
struct SessionBest: Equatable {
    var liftName: String
    var was: Double
    var now: Double
    /// On an assisted machine the number is help, so a record is a smaller
    /// one and the gain is what she stopped needing.
    var assisted = false

    var gain: Double { assisted ? was - now : now - was }
}

// one fixed workout for now, so the loop can be tried before the planner
// exists. names only: the weight, the reps and the number of sets all come
// from the rules, and a hand-written 95 lb squat sitting here was two answers
// to one question with no way to tell which one you were reading
let starterLifts = ["back-squat", "leg-press"]

// "Cable Crossover" -> "custom-cable-crossover"
/// A lift's name from its id, for the places that hold an id and have no
/// logged lift to ask.
func liftName(_ id: String) -> String {
    // the prefix, once, off the front. `replacingOccurrences` took every
    // "custom-" in the id, so a lift she named "Custom Press" became
    // custom-custom-press and read back as "Press": the sets step said
    // Custom Press and the workout under it said something else.
    // Found by a codex audit 2026-11-17.
    let own = id.hasPrefix("custom-") ? String(id.dropFirst("custom-".count)) : id
    return ExerciseLibrary.find(id)?.name
        ?? own.replacingOccurrences(of: "-", with: " ").capitalized
}

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
