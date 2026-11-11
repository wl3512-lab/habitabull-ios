//
// what the home screen is for, today.
//
// The screen has three jobs and they are not the same job, so the choice
// between them is made here rather than inside four nested ifs in the view.
// The rule it encodes, from the 2023 interviews and confirmed in the 2026
// walkthroughs: people will log a workout before they will set anything up.
// So until she has agreed to a week, the home screen asks for a session, not
// for a plan.

import Foundation
import HabitaBullKit

enum HomeShape: Equatable {
    /// No week agreed yet. One session, no setup, nothing to decide first.
    case firstWorkout
    /// A day with a workout on it, whether or not it has been started.
    case plan(String)
    /// Today is logged. Deliberately no orange action: turning up was the
    /// job, and inventing one more would argue against the app's own point.
    case done(lifts: Int)
}

enum Home {
    /// `fallback` is the day's name when there is no session yet to name it.
    static func shape(profile: Profile?, today: Session?, fallback: String = "Leg day") -> HomeShape {
        if let today, today.completedAt != nil { return .done(lifts: today.liftsDone) }
        // something is open today: the screen is about finishing it, even if
        // she never agreed to a week
        if let today { return .plan(today.label) }
        if profile?.weekChosen != true { return .firstWorkout }
        return .plan(fallback)
    }

    /// The headline, which is the one big thing on the screen.
    static func headline(_ shape: HomeShape) -> String {
        switch shape {
        case .firstWorkout: "Your first workout"
        case .plan(let label): label
        case .done: "Logged"
        }
    }
}

// MARK: - history, as the attendance rules want it

extension Session {
    /// Attendance counts a day you showed up, not a day you finished. A
    /// workout abandoned after two sets still happened; one opened and left
    /// empty did not.
    var asRecord: SessionRecord {
        SessionRecord(date: date, completed: completedAt != nil, loggedSet: setsDone > 0)
    }
}

extension SessionStore {
    /// The seven circles under the date: trained, planned, today, still to
    /// come. Sunday first, like the rest of the app and the package.
    func weekStrip(trainingDays: [Int], today: Date = .now) -> [StripDay] {
        let cal = Attendance.calendar()
        return Attendance.weekStrip(sessions.map(\.asRecord), trainingDays: trainingDays,
                                    today: Attendance.day(today, cal))
    }
}
