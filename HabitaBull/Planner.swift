//
// the week as workouts rather than as circles.
//
// Until now every training day was called "Leg day" and had the same two
// lifts on it, which is the single biggest thing the web app has and the
// phone does not. A routine is two small facts: which day of the week is
// which workout, and what each workout contains.
//
// Lifts are kept by the workout's name, not by the weekday, because two
// Mondays called "Push day" are the same workout. Editing one has to edit the
// other or the app is quietly keeping two copies of a decision she made once.

import Foundation
import HabitaBullKit

struct Routine: Codable, Equatable {
    /// One per training day. 0 = Sunday, matching the calendar, the strip and
    /// the rules package.
    struct Day: Codable, Equatable {
        var weekday: Int
        var label: String
    }

    var days: [Day] = []
    /// Workout name to the lifts in it.
    var library: [String: [String]] = [:]
    /// Workouts she has named on days that are currently switched off.
    ///
    /// Replanning builds the week from the days that are on, so a day taken
    /// out of it lost its assignment: Monday, renamed to "Chest and arms",
    /// came back as the app's default Push day with default lifts. She took a
    /// day off the week, she did not throw its workout away. Keeping this on
    /// the routine rather than in the screen means it survives closing the
    /// app, which is the half the first fix missed.
    var remembered: [Int: String] = [:]

    init(days: [Day] = [], library: [String: [String]] = [:], remembered: [Int: String] = [:]) {
        self.days = days
        self.library = library
        self.remembered = remembered
    }

    enum CodingKeys: String, CodingKey { case days, library, remembered }

    /// Lenient, like the profile around it: a routine saved before a field
    /// existed still opens, rather than taking her whole week with it.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        days = try c.decodeIfPresent([Day].self, forKey: .days) ?? []
        library = try c.decodeIfPresent([String: [String]].self, forKey: .library) ?? [:]
        remembered = try c.decodeIfPresent([Int: String].self, forKey: .remembered) ?? [:]
    }

    func label(on weekday: Int) -> String? {
        days.first { $0.weekday == weekday }?.label
    }

    func lifts(on weekday: Int) -> [String]? {
        label(on: weekday).flatMap { library[$0] }
    }

    /// Rename a workout, everywhere it is used.
    ///
    /// The lifts move with the name rather than being left behind under the
    /// old one: she renamed the day, she did not empty it.
    mutating func rename(_ old: String, to fresh: String) {
        let name = fresh.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != old else { return }
        if let lifts = library.removeValue(forKey: old) {
            // a name she is merging into keeps what is already in it
            if library[name] == nil { library[name] = lifts }
        }
        days = days.map { $0.label == old ? Day(weekday: $0.weekday, label: name) : $0 }
        remembered = remembered.mapValues { $0 == old ? name : $0 }
        // and the days she has switched off, which hold a name too. without
        // this, Monday and Thursday sharing Upper day, Thursday off and Monday
        // renamed left Thursday pointing at a name nothing answers to any
        // more: turning it back on gave her the old name and default lifts.
    }

    /// Change what is in a workout. Every day with that name changes with it.
    mutating func setLifts(_ lifts: [String], of label: String) {
        library[label] = lifts
    }

    /// A day she has finished editing: its new name, and the lifts she just
    /// built, in the order that keeps the lifts.
    ///
    /// The other order filed them under the old name and left `rename` to
    /// move them, and `rename` keeps what is already at a name she is merging
    /// into. Editing Push day and renaming it Pull day gave her two Pull days
    /// holding the old Pull day lifts, with the list she had just built gone
    /// and nothing said about it.
    mutating func save(_ lifts: [String], of old: String, renamedTo fresh: String) {
        let wanted = fresh.trimmingCharacters(in: .whitespacesAndNewlines)
        let settled = (wanted.isEmpty || wanted == old) ? old : wanted
        rename(old, to: fresh)
        setLifts(lifts, of: settled)
    }

    /// The days in the order they are read: Sunday first, like everything else.
    var inOrder: [Day] { days.sorted { $0.weekday < $1.weekday } }
}

enum Planner {
    /// Build the week's workouts for the days she has picked, keeping
    /// everything she has already decided.
    ///
    /// A day she has already named keeps its name, and a workout she has
    /// edited keeps its lifts, even if she is not training on it this week.
    /// Adding a fourth day should not quietly rewrite the three she had.
    ///
    /// Handed nothing to keep, it proposes the whole week from scratch, which
    /// is what the first run wants: the app's own three day split is not a
    /// decision of hers to protect, and cutting it to one day should give her
    /// a full body day rather than the push day it had got as far as naming.
    static func plan(for weekdays: [Int], keeping old: Routine? = nil) -> Routine {
        let days = Array(Set(weekdays)).sorted()
        let fresh = Split.labels(days.count)
        var library = old?.library ?? [:]

        let planned: [Routine.Day] = days.enumerated().map { index, weekday in
            let label = old?.label(on: weekday) ?? fresh[safe: index] ?? "Full body"
            if library[label] == nil { library[label] = lifts(for: label) }
            return Routine.Day(weekday: weekday, label: label)
        }
        return Routine(days: planned, library: library)
    }

    /// What a workout of that name starts out containing.
    ///
    /// Three lifts, every time. Four is a longer session than someone two
    /// weeks in will keep, and the day is hers to add to.
    static func lifts(for label: String) -> [String] {
        switch label {
        case "Full body": ["back-squat", "bench-press", "barbell-row"]
        case "Upper day": ["bench-press", "barbell-row", "db-shoulder-press"]
        case "Lower day": ["back-squat", "romanian-deadlift", "leg-press"]
        case "Push day": ["bench-press", "overhead-press", "tricep-pushdown"]
        case "Pull day": ["lat-pulldown", "barbell-row", "db-curl"]
        case "Leg day": ["back-squat", "leg-press", "lying-leg-curl"]
        // a name of her own: a whole body day is the one guess that is wrong
        // in the fewest ways
        default: ["back-squat", "bench-press", "barbell-row"]
        }
    }

    /// The lineup she actually trained, carried back onto the workout it
    /// belongs to. Nil when there is nothing to change.
    ///
    /// The plan is where a session's lifts come from, so without this the day
    /// rebuilds from its original shape every week: the lift she added at the
    /// rack, and the one she swapped out, are both forgotten by next week. It
    /// has been the rule since the web version, the rules package has carried
    /// it since the port as `Planner.remember`, and nothing in the app ever
    /// called it. Found by a codex audit 2026-11-18.
    ///
    /// Only the choice of lifts travels. The weights come back out of her
    /// history every time the workout is built, which is what makes this safe
    /// to do without asking.
    ///
    /// Three things it leaves alone, all of them from the web version. A quick
    /// workout is not a decision about the day it happened to fall on. An
    /// empty one never blanks a day. And a name her week does not use is not a
    /// workout of hers to rewrite.
    static func remembering(_ session: Session, in routine: Routine?) -> Routine? {
        guard var routine, session.label != "Quick workout" else { return nil }
        let lifts = session.exercises.map(\.exerciseId)
        guard !lifts.isEmpty, let known = routine.library[session.label],
              known != lifts else { return nil }
        // every day with that name, which is how editing one works too
        routine.setLifts(lifts, of: session.label)
        return routine
    }

    /// What is planned for a given day of the week, for the screens that have
    /// to answer before a workout exists.
    static func today(_ routine: Routine?, weekday: Int) -> (label: String, lifts: [String])? {
        guard let routine, let label = routine.label(on: weekday) else { return nil }
        return (label, routine.library[label] ?? lifts(for: label))
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
