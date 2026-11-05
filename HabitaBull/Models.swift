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
}

struct Session: Codable, Equatable, Identifiable {
    var id: String
    var date: String        // local day, "2026-11-05"
    var label: String
    var exercises: [LoggedExercise]
    var startedAt: Date
    var completedAt: Date? = nil

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
    var summary: String     // "95 lb × 8", or "8 reps" with no weight
    var resting: Bool       // false when that was the last set of the workout
}

// a lift that beat your old heaviest
struct SessionBest: Equatable {
    var liftName: String
    var was: Double
    var now: Double

    var gain: Double { now - was }
}

// one fixed workout for now, so the loop can be tried before the planner exists
let starterExercises = [
    LoggedExercise(exerciseId: "back-squat", sets: Array(repeating: LoggedSet(weight: 95, reps: 8), count: 3)),
    LoggedExercise(exerciseId: "leg-press", sets: Array(repeating: LoggedSet(weight: 90, reps: 10), count: 3)),
]

// "Cable Crossover" -> "custom-cable-crossover"
func customLiftId(_ name: String) -> String {
    let words = name.lowercased().split { !$0.isLetter && !$0.isNumber }
    return "custom-" + words.joined(separator: "-")
}

// the local calendar day. never UTC: an 11pm workout belongs to today
func dayString(_ date: Date = .now) -> String {
    let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
}
