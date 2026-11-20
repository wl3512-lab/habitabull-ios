//
// the join between the app's words and the rules package's words.
//
// HabitaBullKit knows nothing about this app: it takes plain shapes and
// history and answers what to lift next. Everything that translates between
// the two lives here, so there is one place to look when an answer surprises
// you, and so the rules stay testable without an app around them.

import Foundation
import HabitaBullKit

// MARK: - the app's types, said in the package's terms

extension Exercise {
    /// Only the parts the rules care about: how it loads and what kind of
    /// lift it is. The name, the muscle and the equipment stay here.
    var shape: LiftShape {
        LiftShape(increment: increment, compound: compound, heavy: heavy, hold: hold, cardio: cardio,
                  floor: LiftShape.floor(for: equipment), assisted: assisted)
    }
}

extension Exercise {
    /// The whole lift as the rules see it.
    ///
    /// `shape` above is only how a lift loads, which is all the progression
    /// rules need. Picking lifts needs the muscle and the equipment too, so
    /// the planner gets the lot.
    var asLift: HabitaBullKit.Lift {
        HabitaBullKit.Lift(id: id, name: name, equipment: equipment, primary: primary,
                           increment: increment, compound: compound, heavy: heavy,
                           hold: hold, cardio: cardio, assisted: assisted)
    }
}

extension ExerciseLibrary {
    /// The library as the rules see it, all of it.
    ///
    /// Cardio and timed holds used to be left out, because planning one into a
    /// day would have put a lift on her week that no screen could log. Both
    /// are loggable now, so a cardio day can be filled from the library like
    /// any other. Built once: the planner walks the whole list for every slot.
    static let asLifts: [HabitaBullKit.Lift] = all.map(\.asLift)

    /// Every kind of equipment the library knows.
    ///
    /// The app has never asked her what her gym has, and the honest stand-in
    /// is all of it: she has been logging barbell and machine work since the
    /// first week. A question for her rather than a guess to make quietly.
    static let everyKit: [String] = Array(Set(all.map(\.equipment))).sorted()
}

/// A lift she typed in herself. Nothing is known about it, so it is treated
/// as an ordinary accessory lift that loads in fives, which is the same guess
/// the steppers already make.
let liftOfHerOwn = LiftShape(increment: 5, floor: 5)

extension LoggedExercise {
    var asLoggedLift: HabitaBullKit.LoggedLift {
        HabitaBullKit.LoggedLift(
            exerciseId: exerciseId,
            sets: sets.map { HabitaBullKit.LoggedSet(weight: $0.weight, reps: $0.reps, done: $0.done) }
        )
    }
}

extension Session {
    /// A finished or half-finished workout, as history.
    ///
    /// `oneOff` marks a workout that was not the plan, so the planner does not
    /// read Tuesday's quick arm session as a decision about every Tuesday. A
    /// quick workout is still history for progression: the weight you moved
    /// counts whatever the reason you were there.
    var asTrainingSession: TrainingSession {
        TrainingSession(date: date, label: label, lifts: exercises.map(\.asLoggedLift),
                        oneOff: label == "Quick workout",
                        // the civil day cannot order two workouts a flight
                        // apart: fly west and yesterday's is dated after
                        // today's. Found by a codex audit 2026-11-18.
                        startedAt: startedAt)
    }
}

extension SessionStore {
    /// How hard the plan pushes.
    ///
    /// Onboarding sets this later. Until then everyone is new, which is the
    /// safe end to be wrong on: a new lifter's numbers under someone stronger
    /// are a light day, the other way round is an injury.
    var level: Level {
        Level(rawValue: UserDefaults.standard.string(forKey: "level") ?? "") ?? .new
    }

    /// What to put on the bar next for this lift, and why.
    ///
    /// The open workout is left out of its own history, or the first set you
    /// log would decide what the rest of that same lift should be.
    func nextTarget(of id: String, planningSets planned: Int? = nil) -> Target {
        // the workout she is in is the one to leave out, and not simply the
        // first of today's, nor every unfinished workout the store can still
        // write to: one she walked away from last night is history, not the
        // workout in her hands
        // read once. inside the closure this re-derives per session, and
        // deriving it scans the sessions and builds a Calendar, so planning one
        // lift against two years of history was ninety thousand calendar
        // builds. Today reads this for every lift on the card, every redraw.
        let inHand = sessionInHandId
        let past = sessions.filter { $0.id != inHand }.map(\.asTrainingSession)
        let lift = ExerciseLibrary.find(id)
        let shape = onHerBar(lift?.shape ?? liftOfHerOwn, lift)
        return Progression.next(shape, history: Progression.history(of: id, in: past),
                                level: level, planned: planned ?? setsLastTime(of: id))
    }

    /// Her own bar is the floor under a barbell lift.
    ///
    /// The rules take 45 for a barbell, because that is the bar in most gyms.
    /// She may have told the plate loader hers is 30, and then the back-off
    /// refused to go below 45 and said "This is as light as it loads" while
    /// the loader on the same screen would happily build 35.
    /// Found by a codex audit 2026-11-18.
    private func onHerBar(_ shape: LiftShape, _ lift: Exercise?) -> LiftShape {
        guard lift?.equipment.lowercased() == "barbell" else { return shape }
        let bar = UserDefaults.standard.double(forKey: "barWeight")
        guard bar > 0, bar < shape.floor else { return shape }
        var mine = shape
        mine.floor = bar
        return mine
    }

    /// The sentence under the steppers on the first set: "Up 2.5 lb. You
    /// earned it.", or why it is holding you where you are.
    func reasonForNext(of id: String, planningSets planned: Int? = nil) -> String {
        nextTarget(of: id, planningSets: planned).note
    }

    /// A lift as it should start today: the rules' numbers, and the number of
    /// sets you actually did last time if you did it before.
    func planned(_ id: String) -> LoggedExercise {
        let count = setsLastTime(of: id) ?? nextTarget(of: id).sets
        let target = nextTarget(of: id, planningSets: count)
        return LoggedExercise(
            exerciseId: id,
            sets: Array(repeating: HabitaBull.LoggedSet(weight: target.weight, reps: target.reps),
                        count: max(1, count))
        )
    }

    /// The fixed starter workout with today's numbers in it: what Today shows
    /// before you start, and what you get when you do. Two places reading one
    /// answer, because a preview that disagrees with the thing it previews is
    /// worse than no preview.
    var plannedToday: [LoggedExercise] { starterLifts.map(planned) }
}
