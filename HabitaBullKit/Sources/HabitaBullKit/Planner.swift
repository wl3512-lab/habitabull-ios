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

    public init(id: String, name: String, equipment: String, primary: String, increment: Double,
                compound: Bool, heavy: Bool = false, hold: Bool = false, cardio: Bool = false) {
        self.id = id; self.name = name; self.equipment = equipment; self.primary = primary
        self.increment = increment; self.compound = compound
        self.heavy = heavy; self.hold = hold; self.cardio = cardio
    }

    public var shape: LiftShape {
        LiftShape(increment: increment, compound: compound, heavy: heavy, hold: hold, cardio: cardio)
    }
}

public struct PlannedLift: Sendable, Equatable {
    public var exerciseId: String
    public var sets: Int
    public var reps: Int
    public var weight: Double
}

public struct Routine: Sendable, Equatable {
    /// 0 = Sunday, matching the calendar.
    public var day: Int
    public var label: String
    public var dayType: String
    public var exercises: [PlannedLift]
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

    /// A week of routines, one per training day.
    public static func generate(
        level: Level,
        days trainingDays: [Int],
        equipment: [String],
        favourites: [String] = [],
        dayTypes: [String]? = nil,
        variants: [Int: Int]? = nil,
        catalogue: [Lift]
    ) -> [Routine] {
        let days = Array(Set(trainingDays)).sorted()
        if days.isEmpty { return [] }
        let kit = equipment.isEmpty ? ["bodyweight"] : equipment
        let chosen = (dayTypes?.isEmpty == false) ? dayTypes! : DayTypes.default(dayCount: days.count)

        return days.enumerated().map { i, day in
            let type = DayTypes.named(chosen[i % chosen.count])
            let slot = variants?[day] ?? i
            // Full body alternates its slots so two sessions are never
            // identical; a named day is the same shape every time, which is
            // the point of naming it.
            let muscles = type.id == "full-body" ? fullBody[slot % fullBody.count] : type.muscles

            // A day type that names its lifts skips the picker entirely: the
            // first one her kit allows, and nothing else on the day.
            if let named = type.lifts?.compactMap({ id in catalogue.first { $0.id == id } }), !named.isEmpty {
                let fixed = named.first { kit.contains($0.equipment) } ?? named.last!
                return Routine(day: day, label: type.label, dayType: type.id, exercises: [
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

            let label = type.id == "full-body" ? fullBodyLabels[slot % fullBodyLabels.count] : type.label
            return Routine(day: day, label: label, dayType: type.id, exercises: exercises)
        }
    }
}
