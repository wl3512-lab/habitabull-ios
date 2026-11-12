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
    }

    /// Change what is in a workout. Every day with that name changes with it.
    mutating func setLifts(_ lifts: [String], of label: String) {
        library[label] = lifts
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
