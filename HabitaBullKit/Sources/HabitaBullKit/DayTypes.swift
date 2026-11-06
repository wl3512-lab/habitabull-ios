//
// Named day types, so a week can be planned in the language people use.
//
// Ported from the web app's lib/templates.ts. "Leg day" and "push day" are how
// lifters talk, and a plan you can name is a plan you can hold in your head.
// Full body stays first and stays recommended: ACSM's 2026 update puts novices
// on full-body work across non-consecutive days, because training every group
// twice a week matters more than the split.

public struct DayType: Sendable, Equatable {
    public let id: String
    public let label: String
    public let hint: String
    /// Slots, filled in order. A muscle can repeat; the picker will not reuse a lift.
    public let muscles: [String]
    /// Circuits run lighter and longer, and prefer what needs no setup.
    public let circuit: Bool
    /// Named lifts in preference order, instead of muscle slots. Cardio is the
    /// only day that has them: she is going to the machine everybody knows.
    public let lifts: [String]?
    /// True for the shape the guidance actually recommends for a novice.
    public let recommended: Bool

    init(_ id: String, _ label: String, _ hint: String, _ muscles: [String],
         circuit: Bool = false, lifts: [String]? = nil, recommended: Bool = false) {
        self.id = id; self.label = label; self.hint = hint; self.muscles = muscles
        self.circuit = circuit; self.lifts = lifts; self.recommended = recommended
    }
}

public enum DayTypes {
    public static let all: [DayType] = [
        DayType("full-body", "Full body", "A bit of everything, and the one that works on three days a week",
                ["quads", "hamstrings", "chest", "back", "core"], recommended: true),
        DayType("push", "Push day", "Chest, shoulders, triceps", ["chest", "shoulders", "arms", "chest"]),
        DayType("pull", "Pull day", "Back, biceps, hamstrings", ["back", "hamstrings", "back", "arms"]),
        DayType("legs", "Leg day", "Quads, hamstrings, glutes", ["quads", "hamstrings", "glutes", "quads"]),
        DayType("upper", "Upper body", "Everything above the hips", ["chest", "back", "shoulders", "arms", "core"]),
        DayType("lower", "Lower body", "Everything below the hips", ["quads", "hamstrings", "glutes", "hamstrings"]),
        DayType("cardio", "Cardio", "Treadmill, bike, rower or a run. You set how long",
                ["quads"], circuit: true, lifts: ["treadmill", "outdoor-run"]),
    ]

    /// An unknown id falls back rather than throwing: a stored plan may name a
    /// day type this version has never heard of.
    public static func named(_ id: String) -> DayType {
        all.first { $0.id == id } ?? all[0]
    }

    /// The default week: full body, which is also what the guidance recommends.
    public static func `default`(dayCount: Int) -> [String] {
        Array(repeating: "full-body", count: max(0, dayCount))
    }

    /// Whether a week of chosen day types trains everything at least twice.
    /// Not a blocker. It drives one honest line under the picker: somebody
    /// running push/pull/legs three days a week should know each group gets
    /// trained once, and then decide for themselves.
    public static func coversTwiceWeekly(_ ids: [String]) -> Bool {
        var counts: [String: Int] = [:]
        for id in ids {
            for m in Set(named(id).muscles) { counts[m, default: 0] += 1 }
        }
        return ["quads", "chest", "back"].allSatisfy { (counts[$0] ?? 0) >= 2 }
    }
}
