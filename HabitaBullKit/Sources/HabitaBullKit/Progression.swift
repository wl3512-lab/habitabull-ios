//
// What to lift next, and why.
//
// Ported from the web app's lib/engine.ts, rule for rule and note for note.
// The notes are the app's own words and they go on screen, so they are copied
// exactly rather than rewritten.
//
// The rules take plain numbers rather than the app's models on purpose: a set
// is a weight and a count of reps, and a lift is five facts about how it is
// loaded. Nothing in here knows what a Session is, which is what lets it run
// without a phone.

import Foundation

public enum Level: String, Codable, Sendable, CaseIterable {
    case new, returning, experienced
}

/// A set that actually happened.
public struct DoneSet: Sendable, Equatable {
    public var weight: Double
    public var reps: Int

    public init(weight: Double, reps: Int) {
        self.weight = weight
        self.reps = reps
    }
}

/// The five things the rules need to know about a lift.
public struct LiftShape: Sendable, Equatable {
    /// The smallest real jump in weight. Zero means the lift carries no load.
    public var increment: Double
    /// Compounds carry the session and progress slower.
    public var compound: Bool
    /// Trained heavy and low by convention. A novice deadlifting for ten is
    /// the clearest sign nobody looked at the programme.
    public var heavy: Bool
    /// Reps are seconds: a plank, not a weighted crunch.
    public var hold: Bool
    /// Time rather than sets: one block, logged in minutes.
    public var cardio: Bool
    /// The lightest this lift actually loads: an empty bar is 45, the lightest
    /// dumbbell on the rack is 5. Only the back-off uses it, and only to stop
    /// cutting. Without it a run of hard sessions takes 10% off the 10% off
    /// the 10%, and a compliant lifter is squatting an unloadable 17.5 lb six
    /// weeks later. Zero means no floor, which is what bodyweight wants.
    public var floor: Double

    public init(increment: Double, compound: Bool = false, heavy: Bool = false, hold: Bool = false,
                cardio: Bool = false, floor: Double = 0) {
        self.increment = increment
        self.compound = compound
        self.heavy = heavy
        self.hold = hold
        self.cardio = cardio
        self.floor = floor
    }
}

extension LiftShape {
    /// The lightest the equipment actually goes, by what it is.
    ///
    /// One rule, so the planner and the app cannot disagree about where a
    /// back-off stops. The numbers are a typical gym rather than a universal
    /// truth, and being a little conservative is the right way to be wrong:
    /// the cost of a floor set too high is one session that felt easy.
    public static func floor(for equipment: String) -> Double {
        switch equipment.lowercased() {
        case "barbell": return 45       // the empty bar, and there is no below
        case "dumbbell": return 5       // the lightest pair on the rack
        case "kettlebell": return 10    // the lightest bell
        case "machine": return 10       // one plate on the stack
        default: return 0               // bodyweight, and anything unrecognised
        }
    }
}

public struct Target: Sendable, Equatable {
    public var weight: Double
    public var reps: Int
    public var sets: Int
    /// One line to the person about to lift. Shown as written.
    public var note: String
}

/// A set as it was logged, before anything decides whether it counts.
public struct LoggedSet: Sendable, Equatable {
    public var weight: Double
    public var reps: Int
    public var done: Bool

    public init(weight: Double, reps: Int, done: Bool) {
        self.weight = weight; self.reps = reps; self.done = done
    }
}

public struct LoggedLift: Sendable, Equatable {
    public var exerciseId: String
    public var sets: [LoggedSet]

    public init(exerciseId: String, sets: [LoggedSet]) {
        self.exerciseId = exerciseId; self.sets = sets
    }
}

public struct TrainingSession: Sendable, Equatable {
    /// Local day, "2026-11-06".
    public var date: String
    /// What the workout was called, which is how a day recognises its own
    /// session when the week is written back to.
    public var label: String
    public var lifts: [LoggedLift]
    /// A session that is not a statement about the day it fell on: a quick
    /// workout with no plan behind it, or a day rebuilt around something that
    /// hurts. Both are right for today and neither redefines Thursday.
    public var oneOff: Bool

    public init(date: String, label: String = "", lifts: [LoggedLift], oneOff: Bool = false) {
        self.date = date; self.label = label; self.lifts = lifts; self.oneOff = oneOff
    }
}

public enum Progression {
    static let baseLoad: [Level: Double] = [.new: 45, .returning: 65, .experienced: 95]
    static let levelSets: [Level: Int] = [.new: 3, .returning: 3, .experienced: 4]
    /// Working reps for the compounds. Ten was too many for a novice squat and
    /// far too many for a novice deadlift; the accessories are where higher
    /// reps belong.
    static let levelReps: [Level: Int] = [.new: 8, .returning: 6, .experienced: 5]

    public static func sets(for level: Level) -> Int { levelSets[level] ?? 3 }

    /// Working reps for one lift. The single source of truth: this used to be
    /// decided separately in the generator, the target calculator and the
    /// rebuild, and they disagreed.
    public static func reps(_ lift: LiftShape, level: Level) -> Int {
        if lift.hold { return 30 }          // seconds, for anything you hold
        if lift.cardio { return 20 }        // minutes, and the same at every level
        let base = levelReps[level] ?? 8
        if lift.heavy { return min(5, base) }
        return lift.compound ? base : base + 4
    }

    /// A weight you can actually load. Never below one increment.
    public static func round(_ weight: Double, to increment: Double) -> Double {
        guard increment > 0 else { return 0 }
        return Swift.max(increment, (weight / increment).rounded() * increment)
    }

    /// A weight you can load, and never heavier than what was asked for.
    ///
    /// Only the back-off uses this. Rounding to the nearest loadable weight
    /// can land back where she started -- 10% off 12.5 lb is 11.25, which is
    /// nearer 12.5 than 10 -- and a back-off that does not back off is worse
    /// than none, because the app then says it cut while the number sits
    /// still. Going down is always available and always honest.
    static func roundDown(_ weight: Double, to increment: Double) -> Double {
        guard increment > 0 else { return 0 }
        return Swift.max(increment, (weight / increment).rounded(.down) * increment)
    }

    public static func startingWeight(_ lift: LiftShape, level: Level) -> Double {
        guard lift.increment > 0 else { return 0 }   // bodyweight
        let base = baseLoad[level] ?? 45
        return round(lift.compound ? base : base * 0.45, to: lift.increment)
    }

    /// Every logged set of a lift, newest session first.
    ///
    /// This is the step `next` depends on and the easiest one to get wrong, so
    /// it lives here rather than in whatever screen happens to need it.
    ///
    /// Three rules, all from the web version. Sessions are ordered by date, not
    /// by the order they sit in storage. A set counts whether or not she ever
    /// pressed Finish, because End is where most sessions actually stop and
    /// requiring Finish made the ordinary gym session invisible. A session she
    /// opened and logged nothing in contributes nothing: it is dropped, so a
    /// lift with no history reads as a lift with no history.
    public static func history(of exerciseId: String, in sessions: [TrainingSession]) -> [[DoneSet]] {
        sessions
            .sorted { $0.date > $1.date }
            .map { session in
                session.lifts
                    .filter { $0.exerciseId == exerciseId }
                    .flatMap { $0.sets }
                    .filter(\.done)
                    .map { DoneSet(weight: $0.weight, reps: $0.reps) }
            }
            .filter { !$0.isEmpty }
    }

    /// What to put on the bar next.
    ///
    /// `history` is the sessions that logged this lift, newest first, each one
    /// the sets completed in it. A session she opened and never lifted in is
    /// not history and must not be in this list.
    /// - Parameter planned: how many sets she is actually going to do, when
    ///   that is already known. The app plans a lift from the number of sets
    ///   she did last time, so a lift she settled at two can be below the
    ///   level's three. Judging "did she clear it" against the level's count
    ///   then means clearing every rep of both sets still reads as a miss, and
    ///   the weight never moves again. Left out, the level decides, which is
    ///   what the web version did and what the parity fixtures pin.
    public static func next(_ lift: LiftShape, history: [[DoneSet]], level: Level,
                            planned: Int? = nil) -> Target {
        let targetReps = reps(lift, level: level)
        // Cardio is one block of time, not a set count. Everything else keeps
        // the level's count, unless the caller knows better.
        let setCount = lift.cardio ? 1 : max(1, planned ?? sets(for: level))

        guard let last = history.first else {
            return Target(weight: startingWeight(lift, level: level), reps: targetReps, sets: setCount,
                          note: "First time. Start light and learn the movement.")
        }

        let lastWeight = last.map(\.weight).max() ?? startingWeight(lift, level: level)

        // Cardio carries its incline and nothing else. The field holds a
        // percent rather than a load, so none of the progression below applies
        // to it, and resetting it to flat every session is the other wrong
        // answer: she set 5% on Monday and found 0% on Wednesday.
        if lift.cardio {
            return Target(weight: lastWeight, reps: targetReps, sets: setCount,
                          note: "Same as last time. Change the time or the incline if you want to.")
        }

        let clearedAll = last.count >= setCount && last.allSatisfy { $0.reps >= targetReps }
        if clearedAll {
            let weight = lift.increment == 0 ? 0 : round(lastWeight + lift.increment, to: lift.increment)
            // What "more" means depends on what the lift is counted in. On a
            // lift the app cannot load, going longer is the user's call.
            let more = lift.cardio || lift.hold ? "Go a little longer this time." : "Add two reps this time."
            let note = lift.increment == 0 ? more : "Up \(trim(lift.increment)) lb. You earned it."
            return Target(weight: weight, reps: targetReps, sets: setCount, note: note)
        }

        let recent = history.prefix(3)
        let missed = recent.filter { !($0.isEmpty == false && $0.allSatisfy { $0.reps >= targetReps }) }.count
        if missed >= 3 && history.count >= 3 {
            let cut = lift.increment == 0 ? 0 : max(roundDown(lastWeight * 0.9, to: lift.increment), lift.floor)
            // A lift already at its lightest cannot be backed off. Printing
            // "backing off 10%" over a number that did not move would be the
            // app describing something it did not do, so it says the true
            // thing instead: there is nowhere lighter to go. Reaching this is
            // now the floor's doing and only the floor's, because the cut
            // rounds down and so always has somewhere to go until it does not.
            if lift.increment > 0 && cut >= lastWeight {
                return Target(weight: lastWeight, reps: targetReps, sets: setCount,
                              note: "This is as light as it loads. Stay here until it moves.")
            }
            return Target(weight: cut, reps: targetReps, sets: setCount,
                          note: "Backing off 10%. Three tough sessions is a signal, not a failure.")
        }

        // Snap even when holding: a hand-typed 97 should come back as a bar you
        // can actually load, not follow her around forever.
        let held = lift.increment == 0 ? 0 : round(lastWeight, to: lift.increment)
        return Target(weight: held, reps: targetReps, sets: setCount, note: "Same weight. Own it this time.")
    }

    /// "2.5" rather than "2.5000", and "5" rather than "5.0".
    ///
    /// The range check is not pedantry: this is the one place in the package
    /// that turns an unchecked Double into an Int, and a stored lift with a
    /// nonsense increment would take the app down rather than print oddly.
    private static func trim(_ n: Double) -> String {
        guard n == n.rounded(), n.magnitude < 1e15 else { return String(n) }
        return String(Int(n))
    }
}
