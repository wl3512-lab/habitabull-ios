//
// the lift list, copied from the web app's lib/exercises.ts into exercises.json.
// it ships inside the app, so it works with no signal

import Foundation

struct Exercise: Codable, Identifiable {
    var id: String
    var name: String
    var equipment: String
    var primary: String     // the main muscle
    var increment: Double   // the step for weight. 0 means bodyweight
    var cardio: Bool
    var hold: Bool
    var startWeight: Double
    var startReps: Int
    /// Carries the session, and progresses more slowly. The planner needs it.
    var compound: Bool = false
    /// Trained heavy and low by convention: a novice deadlifting for ten is
    /// the clearest sign nobody looked at the programme.
    var heavy: Bool = false
    /// A cardio machine whose incline you can set.
    var incline: Bool = false
    /// The number on this machine is help, not load. More of it is easier.
    var assisted: Bool = false

    // Written by hand rather than synthesised so a library file saved before
    // these three existed still reads, instead of failing the whole decode and
    // leaving the app with no lifts at all.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        equipment = try c.decode(String.self, forKey: .equipment)
        primary = try c.decode(String.self, forKey: .primary)
        increment = try c.decode(Double.self, forKey: .increment)
        cardio = try c.decodeIfPresent(Bool.self, forKey: .cardio) ?? false
        hold = try c.decodeIfPresent(Bool.self, forKey: .hold) ?? false
        startWeight = try c.decode(Double.self, forKey: .startWeight)
        startReps = try c.decode(Int.self, forKey: .startReps)
        compound = try c.decodeIfPresent(Bool.self, forKey: .compound) ?? false
        heavy = try c.decodeIfPresent(Bool.self, forKey: .heavy) ?? false
        incline = try c.decodeIfPresent(Bool.self, forKey: .incline) ?? false
        assisted = try c.decodeIfPresent(Bool.self, forKey: .assisted) ?? false
    }
}

enum ExerciseLibrary {
    static let all: [Exercise] = {
        guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Exercise].self, from: data) else { return [] }
        return list
    }()

    // cardio and timed holds don't fit weight and reps, so they wait until they
    // have their own screens
    static let liftable = all.filter { !$0.cardio && !$0.hold }

    /// Lifts a goal can be set on. A goal is a number of pounds to reach, so
    /// it needs a lift that is loaded in pounds and gets harder as that number
    /// grows. An assisted machine fails the second half: its number is help,
    /// so a suggestion offered her more of it to aim for, and a real target of
    /// 40 lb of help after logging 45 counted as already met.
    static let forGoals = liftable.filter { $0.increment > 0 && !$0.assisted }

    static func find(_ id: String) -> Exercise? {
        all.first { $0.id == id }
    }
}
