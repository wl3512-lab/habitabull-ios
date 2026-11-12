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
    /// A day she did not pick, with nothing open on it. The app has no
    /// business naming a workout today, and no business stopping her either.
    case rest
    /// Today is logged. Deliberately no orange action: turning up was the
    /// job, and inventing one more would argue against the app's own point.
    case done(lifts: Int)
}

enum Home {
    /// `fallback` is the day's name when there is no session yet to name it.
    ///
    /// The launch screen reads this same answer, so the two cannot disagree:
    /// a splash that says rest day in front of a home screen that says Leg
    /// day is the app arguing with itself one tap apart.
    static func shape(profile: Profile?, today: Session?, fallback: String = "Leg day",
                      now: Date = .now, calendar: Calendar = Attendance.calendar()) -> HomeShape {
        if let today, today.completedAt != nil { return .done(lifts: today.liftsDone) }
        // something is open today: the screen is about finishing it, even if
        // she never agreed to a week, and even on a day off
        if let today { return .plan(today.label) }
        // placed days are not agreed days. until she has chosen a week there
        // is nothing to call a rest day.
        guard let profile, profile.weekChosen else { return .firstWorkout }
        let weekday = calendar.component(.weekday, from: now) - 1   // 0 = Sunday
        guard profile.trainingDays.contains(weekday) else { return .rest }
        // the day's own name, if she has a routine. `fallback` is what the
        // app called every day before routines existed, and what a profile
        // saved back then still reads as.
        return .plan(profile.routine?.label(on: weekday) ?? fallback)
    }

    /// The headline, which is the one big thing on the screen.
    static func headline(_ shape: HomeShape) -> String {
        switch shape {
        case .firstWorkout: "Your first workout"
        case .plan(let label): label
        case .rest: "Rest day"
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
