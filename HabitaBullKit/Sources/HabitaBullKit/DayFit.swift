//
// What a day type is for, and what to call a day that has grown past it.
//
// Ported from the web app's lib/day-fit.ts. A leg day with an ab crunch on it
// is not a leg day any more, and pretending it is costs her twice: Leg day
// stops meaning legs everywhere else in the week, and the workout she actually
// built has no name of its own to find it by.
//
// The fit is wider than the muscle slots the generator fills a day from. A
// calf raise is not one of Leg day's slots and is still obviously leg work,
// and asking "save this as Legs and calves?" would be the app not knowing what
// a leg is. Full body fits everything by definition.

public enum DayFit {
    /// nil means the day type fits anything.
    static func fits(_ dayType: String?) -> [String]? {
        switch dayType ?? "full-body" {
        case "full-body": nil
        case "push": ["chest", "shoulders", "arms"]
        // Rear delts and face pulls are pull work, filed under shoulders.
        case "pull": ["back", "hamstrings", "arms", "shoulders"]
        case "legs", "lower": ["quads", "hamstrings", "glutes", "calves"]
        case "upper": ["chest", "back", "shoulders", "arms", "core"]
        case "cardio": ["cardio"]
        default: nil
        }
    }

    /// How each group is said in a workout's name. Four leg muscles are one word.
    static func word(for group: String) -> String {
        switch group {
        case "quads", "hamstrings", "glutes", "calves": "legs"
        case "core": "abs"
        default: group     // chest, back, shoulders, arms, cardio
        }
    }

    /// The day type as the first word of a new name: "Legs and abs", not
    /// "Leg day and abs".
    static func base(_ dayType: String?) -> String {
        switch dayType ?? "full-body" {
        case "push": "Push"
        case "pull": "Pull"
        case "legs": "Legs"
        case "lower": "Lower body"
        case "upper": "Upper body"
        case "cardio": "Cardio"
        default: "Full body"
        }
    }

    static func group(of exerciseId: String, in catalogue: [Lift]) -> String? {
        guard let lift = catalogue.first(where: { $0.id == exerciseId }) else { return nil }
        return lift.cardio ? "cardio" : lift.primary
    }

    /// The lifts on a day its type does not cover, in the order they sit.
    /// A lift the library cannot resolve is left out rather than guessed at.
    public static func offType(_ dayType: String?, exercises: [PlannedLift], catalogue: [Lift]) -> [String] {
        guard let fits = fits(dayType) else { return [] }
        return exercises.map(\.exerciseId).filter { id in
            guard let g = group(of: id, in: catalogue) else { return false }
            return !fits.contains(g)
        }
    }

    /// What a lift adds to a day, in a word: "abs", "chest", "legs".
    public static func groupWord(_ exerciseId: String, catalogue: [Lift]) -> String? {
        group(of: exerciseId, in: catalogue).map(word(for:))
    }

    /// Off-type lifts that bring a group the day did not already have.
    ///
    /// The question is about the day changing shape, not about every lift: a
    /// second ab lift on a leg day that already kept one changes nothing worth
    /// a new name.
    public static func offTypeBeyond(
        _ dayType: String?, exercises: [PlannedLift], before: [String], catalogue: [Lift]
    ) -> [String] {
        let had = Set(before.compactMap { group(of: $0, in: catalogue) })
        return offType(dayType, exercises: exercises, catalogue: catalogue).filter { id in
            guard let g = group(of: id, in: catalogue) else { return false }
            return !before.contains(id) && !had.contains(g)
        }
    }

    /// A first name for a day that has grown past its type: "Legs and abs",
    /// "Push, abs and legs". A starting point she can type over.
    public static func mixedName(_ dayType: String?, offIds: [String], catalogue: [Lift]) -> String {
        let base = base(dayType)
        var words: [String] = []
        for id in offIds {
            guard let g = group(of: id, in: catalogue) else { continue }
            let w = word(for: g)
            if w != base.lowercased() && !words.contains(w) { words.append(w) }
        }
        let extra = Array(words.prefix(3))
        if extra.isEmpty { return base }
        if extra.count == 1 { return "\(base) and \(extra[0])" }
        return "\(base), \(extra.dropLast().joined(separator: ", ")) and \(extra[extra.count - 1])"
    }
}

/// A day of the week as the week editor holds it: which workout it is, and
/// what is on it. `workoutId` links a day to one of her saved workouts.
public struct WeekDay: Sendable, Equatable {
    public var day: Int
    public var label: String
    public var dayType: String?
    public var workoutId: String?
    public var exercises: [PlannedLift]

    public init(day: Int, label: String, dayType: String? = nil, workoutId: String? = nil, exercises: [PlannedLift]) {
        self.day = day; self.label = label; self.dayType = dayType
        self.workoutId = workoutId; self.exercises = exercises
    }
}

extension DayFit {
    /// Which days in a week are the same workout as this one, itself included.
    ///
    /// A day linked to a saved workout is the same as every day linked to it.
    /// Otherwise days of the same type with the same name are: Monday's and
    /// Thursday's "Leg day" are one leg day. "Full body A" and "Full body B"
    /// share a type and are deliberately two different workouts, which is why
    /// the name is part of it.
    public static func sameWorkoutDays(_ days: [WeekDay], at index: Int) -> [Int] {
        guard days.indices.contains(index) else { return [] }
        let me = days[index]
        func same(_ r: WeekDay) -> Bool {
            if let mine = me.workoutId { return r.workoutId == mine }
            return r.workoutId == nil
                && (r.dayType ?? "full-body") == (me.dayType ?? "full-body")
                && r.label == me.label
        }
        return days.indices.filter { same(days[$0]) }
    }

    /// Carry one day's lineup to every day that is the same workout.
    ///
    /// It carries which lifts and in what order, never the numbers: each other
    /// day keeps its own sets, reps and weight for a lift it already had, and a
    /// lift new to it arrives as it was planned on the day it came from. What a
    /// single session logged is that session's business.
    public static func shareLineup(_ week: [WeekDay], from at: Int) -> [WeekDay] {
        guard week.indices.contains(at), !week[at].exercises.isEmpty else { return week }
        let from = week[at]
        let twins = Set(sameWorkoutDays(week, at: at).filter { $0 != at })
        if twins.isEmpty { return week }
        return week.indices.map { i in
            guard twins.contains(i) else { return week[i] }
            var day = week[i]
            day.exercises = from.exercises.map { e in
                day.exercises.first { $0.exerciseId == e.exerciseId } ?? e
            }
            return day
        }
    }
}
