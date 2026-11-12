//
// what shape a week is, by how many days are in it.
//
// The app used to call every training day "Leg day" and put the same two
// lifts on it, which is fine for one day a week and nonsense for four. This
// is the oldest, least clever answer to the question, and that is deliberate:
// a beginner who trains three days a week does push, pull and legs, and a
// novel split invented by an app is a split nobody can look up.
//
// Only the names live here. Which lifts a name means needs the exercise
// library, which is the app's, so that part stays on the app's side.

import Foundation

public enum Split {
    /// The day names for a week of `count` training days, in the order they
    /// are handed out across the days she picked.
    ///
    /// One day a week is a full body day rather than a push day, because a
    /// week with one push day in it is a week with no legs in it. Four days
    /// repeats upper and lower rather than inventing Upper A and Upper B: the
    /// weights move every session, so the same name twice is not the same
    /// workout twice.
    public static func labels(_ count: Int) -> [String] {
        switch count {
        case ..<1: []
        case 1: ["Full body"]
        case 2: ["Upper day", "Lower day"]
        case 3: ["Push day", "Pull day", "Leg day"]
        case 4: ["Upper day", "Lower day", "Upper day", "Lower day"]
        case 5: ["Push day", "Pull day", "Leg day", "Upper day", "Lower day"]
        case 6: ["Push day", "Pull day", "Leg day", "Push day", "Pull day", "Leg day"]
        default: ["Push day", "Pull day", "Leg day", "Push day", "Pull day", "Leg day",
                  "Full body"]
        }
    }

    /// Every name this file can hand out, for the screens that have to know
    /// what a day could be called before she has renamed it.
    public static let known = ["Full body", "Upper day", "Lower day",
                               "Push day", "Pull day", "Leg day"]
}
