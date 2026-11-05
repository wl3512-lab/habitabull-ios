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

    static func find(_ id: String) -> Exercise? {
        all.first { $0.id == id }
    }
}
