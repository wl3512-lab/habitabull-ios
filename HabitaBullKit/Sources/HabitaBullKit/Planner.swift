//
// Building a week, and picking the lift that fills a slot.
//
// Ported from the web app's lib/engine.ts (pickExercise, generateRoutine).
// Deterministic: the same inputs always give the same plan, which matters
// because the user has to be able to trust it.
//
// The catalogue is passed in rather than owned here. The rules do not care
// where the list of lifts comes from, and handing it in is what lets a test
// check this against the web engine using the web engine's own library.

import Foundation

/// A lift, as the planner needs it.
public struct Lift: Sendable, Equatable, Codable {
    public var id: String
    public var name: String
    public var equipment: String
    public var primary: String
    public var increment: Double
    public var compound: Bool
    public var heavy: Bool
    public var hold: Bool
    public var cardio: Bool
    /// The number on this lift is help rather than load. The app's own
    /// `Exercise` has carried this since the assisted fixes went in; this one
    /// did not, so a lift described to the planner lost it on the way to its
    /// shape and was planned as though its counterweight were a load.
    /// Nothing in the app plans through here today, which is why no test
    /// could see it. Found by a codex audit 2026-11-17.
    public var assisted: Bool

    public init(id: String, name: String, equipment: String, primary: String, increment: Double,
                compound: Bool, heavy: Bool = false, hold: Bool = false, cardio: Bool = false,
                assisted: Bool = false) {
        self.id = id; self.name = name; self.equipment = equipment; self.primary = primary
        self.increment = increment; self.compound = compound
        self.heavy = heavy; self.hold = hold; self.cardio = cardio
        self.assisted = assisted
    }

    /// Spelled out so that `assisted` may be missing.
    ///
    /// The default on the initialiser above does nothing for decoding: a
    /// synthesised `init(from:)` requires every non-optional key, so adding
    /// `assisted` to a public `Codable` type made every lift encoded before
    /// today throw `keyNotFound`. The app's own `Exercise` has always used
    /// `decodeIfPresent` for the same reason. Found by a codex audit
    /// 2026-11-17.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        equipment = try c.decode(String.self, forKey: .equipment)
        primary = try c.decode(String.self, forKey: .primary)
        increment = try c.decode(Double.self, forKey: .increment)
        compound = try c.decode(Bool.self, forKey: .compound)
        heavy = try c.decodeIfPresent(Bool.self, forKey: .heavy) ?? false
        hold = try c.decodeIfPresent(Bool.self, forKey: .hold) ?? false
        cardio = try c.decodeIfPresent(Bool.self, forKey: .cardio) ?? false
        assisted = try c.decodeIfPresent(Bool.self, forKey: .assisted) ?? false
    }

    public var shape: LiftShape {
        LiftShape(increment: increment, compound: compound, heavy: heavy, hold: hold, cardio: cardio,
                  floor: LiftShape.floor(for: equipment), assisted: assisted)
    }
}

public struct PlannedLift: Sendable, Equatable {
    public var exerciseId: String
    public var sets: Int
    public var reps: Int
    public var weight: Double

    /// Spelled out because the synthesised one is internal to the package,
    /// and the app has to build these now: the day-fit rules take a planned
    /// day, and the day she is editing on screen is the app's own list of
    /// lifts. Nothing outside the package could describe a day to the rules
    /// it was written for.
    public init(exerciseId: String, sets: Int, reps: Int, weight: Double) {
        self.exerciseId = exerciseId
        self.sets = sets
        self.reps = reps
        self.weight = weight
    }
}

/// A day of the planned week.
///
/// One type for the whole package: the planner returns these and the day-fit
/// rules take them. They were two types for a while, which meant the week the
/// planner built could not be handed to the rules that decide which days share
/// a workout without a conversion by hand, and the conversion was exactly
/// where a missing day type would have gone unnoticed.
public struct PlannedDay: Sendable, Equatable {
    /// 0 = Sunday, matching the calendar and the chosen training days.
    public var day: Int
    public var label: String
    public var dayType: String?
    /// Set when this day is one of her saved workouts.
    public var workoutId: String?
    public var exercises: [PlannedLift]

    public init(day: Int, label: String, dayType: String? = nil,
                workoutId: String? = nil, exercises: [PlannedLift]) {
        self.day = day; self.label = label; self.dayType = dayType
        self.workoutId = workoutId; self.exercises = exercises
    }
}

public enum Planner {
    static let fullBody: [[String]] = [
        ["quads", "hamstrings", "chest", "back", "core"],
        ["glutes", "quads", "shoulders", "back", "arms"],
    ]
    static let fullBodyLabels = ["Full body A", "Full body B"]

    /// The best available lift for a muscle, given the kit.
    ///
    /// A starred lift wins between two that would both do the job; compounds
    /// come first otherwise, because they carry the session and progress
    /// cleanly. Ties keep the catalogue's own order, which is what makes the
    /// whole week reproducible.
    public static func pick(
        muscle: String,
        from catalogue: [Lift],
        equipment: [String],
        exclude: Set<String> = [],
        favourites: [String] = [],
        variant: Int = 0
    ) -> Lift? {
        let usable = catalogue.enumerated().filter { _, e in
            e.primary == muscle && equipment.contains(e.equipment) && !exclude.contains(e.id)
        }
        if usable.isEmpty { return nil }
        let starred = Set(favourites)
        // Sorted by hand rather than with `sorted(by:)`: Swift's sort is not
        // guaranteed stable and the web's is, so a tie has to keep its place.
        let ranked = usable.sorted { a, b in
            let aStar = starred.contains(a.element.id), bStar = starred.contains(b.element.id)
            if aStar != bStar { return aStar }
            if a.element.compound != b.element.compound { return a.element.compound }
            return a.offset < b.offset
        }
        let i = ((variant % ranked.count) + ranked.count) % ranked.count
        return ranked[i].element
    }

    /// Carry the lineup she actually trained back onto the day it belongs to.
    ///
    /// The plan is where a session's lifts come from, so without this the day
    /// rebuilds from its original shape every week and the lift she added at
    /// the rack, or the one she dropped, is forgotten by the next session.
    /// Only the choice of lifts and how many sets travels; the weights come
    /// back out of her history every time the session is built.
    ///
    /// Three exemptions, all from the web version. A quick workout is not a
    /// decision about the day it happened to fall on. Neither is a day rebuilt
    /// around an injury. And an empty session never blanks a day.
    ///
    /// It writes to the day with the same weekday *and* the same name, because
    /// "Full body A" and "Full body B" share a weekday rotation and are two
    /// different workouts.
    public static func remember(
        _ session: TrainingSession, in week: [PlannedDay], zone: TimeZone = .current
    ) -> [PlannedDay] {
        if session.oneOff || session.lifts.isEmpty { return week }
        let cal = Attendance.calendar(zone)
        guard let date = Attendance.date(session.date, cal) else { return week }
        let weekday = cal.component(.weekday, from: date) - 1

        return week.map { day in
            guard day.day == weekday, day.label == session.label else { return day }
            var updated = day
            updated.exercises = session.lifts.map { lift in
                // The first set is the one the day comes back at: what she
                // opened with, not what she finished on, which is the same
                // reading the web takes.
                let first = lift.sets.first
                let known = day.exercises.first { $0.exerciseId == lift.exerciseId }
                return PlannedLift(
                    exerciseId: lift.exerciseId,
                    sets: lift.sets.count,
                    reps: first?.reps ?? known?.reps ?? 10,
                    weight: first?.weight ?? 0
                )
            }
            return updated
        }
    }

    /// An index that lands inside the array however odd the number is.
    static func wrap(_ i: Int, _ count: Int) -> Int {
        count > 0 ? ((i % count) + count) % count : 0
    }

    /// A week of routines, one per training day.
    public static func generate(
        level: Level,
        days trainingDays: [Int],
        equipment: [String],
        favourites: [String] = [],
        dayTypes: [String]? = nil,
        variants: [Int: Int]? = nil,
        catalogue: [Lift]
    ) -> [PlannedDay] {
        let days = Array(Set(trainingDays)).sorted()
        if days.isEmpty { return [] }
        let kit = equipment.isEmpty ? ["bodyweight"] : equipment
        let chosen = (dayTypes?.isEmpty == false) ? dayTypes! : DayTypes.default(dayCount: days.count)

        return days.enumerated().map { i, day in
            let type = DayTypes.named(chosen[i % chosen.count])
            // The slot is more than an index: it also rotates which core lift
            // a full-body day gets, so it has to keep its real value. Only the
            // two places that index an array are wrapped, because a stored
            // week can hand back any integer and a negative one used to read
            // off the front of the shapes and trap.
            let slot = variants?[day] ?? i
            // Full body alternates its slots so two sessions are never
            // identical; a named day is the same shape every time, which is
            // the point of naming it.
            let muscles = type.id == "full-body" ? fullBody[wrap(slot, fullBody.count)] : type.muscles

            // A day type that names its lifts skips the picker entirely: the
            // first one her kit allows, and nothing else on the day.
            if let named = type.lifts?.compactMap({ id in catalogue.first { $0.id == id } }), !named.isEmpty {
                let fixed = named.first { kit.contains($0.equipment) } ?? named.last!
                return PlannedDay(day: day, label: type.label, dayType: type.id, exercises: [
                    PlannedLift(exerciseId: fixed.id,
                                sets: 1,                                    // continuous work is one block
                                reps: Progression.reps(fixed.shape, level: level),
                                weight: 0)                                  // flat to start; the incline is hers
                ])
            }

            var used = Set<String>()
            var exercises: [PlannedLift] = []
            for m in muscles {
                // A circuit wants things you can start immediately, so
                // bodyweight first. Core rotates by day so the week is not the
                // same plank five times over.
                let v = m == "core" ? slot : 0
                let found = type.circuit
                    ? pick(muscle: m, from: catalogue, equipment: ["bodyweight"], exclude: used, favourites: favourites, variant: v)
                        ?? pick(muscle: m, from: catalogue, equipment: kit, exclude: used, favourites: favourites, variant: v)
                    : pick(muscle: m, from: catalogue, equipment: kit, exclude: used, favourites: favourites, variant: v)
                        ?? pick(muscle: m, from: catalogue, equipment: ["bodyweight"], exclude: used, favourites: favourites, variant: v)
                guard let ex = found else { continue }
                used.insert(ex.id)
                let reps = Progression.reps(ex.shape, level: level)
                exercises.append(PlannedLift(
                    exerciseId: ex.id,
                    sets: Progression.sets(for: level),
                    reps: type.circuit ? max(15, reps * 2) : reps,
                    weight: type.circuit ? 0 : Progression.startingWeight(ex.shape, level: level)
                ))
            }

            let label = type.id == "full-body" ? fullBodyLabels[wrap(slot, fullBodyLabels.count)] : type.label
            return PlannedDay(day: day, label: label, dayType: type.id, exercises: exercises)
        }
    }
}
