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

    public init(increment: Double, compound: Bool = false, heavy: Bool = false, hold: Bool = false, cardio: Bool = false) {
        self.increment = increment
        self.compound = compound
        self.heavy = heavy
        self.hold = hold
        self.cardio = cardio
    }
}

public struct Target: Sendable, Equatable {
    public var weight: Double
    public var reps: Int
    public var sets: Int
    /// One line to the person about to lift. Shown as written.
    public var note: String
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

    public static func startingWeight(_ lift: LiftShape, level: Level) -> Double {
        guard lift.increment > 0 else { return 0 }   // bodyweight
        let base = baseLoad[level] ?? 45
        return round(lift.compound ? base : base * 0.45, to: lift.increment)
    }

    /// What to put on the bar next.
    ///
    /// `history` is the sessions that logged this lift, newest first, each one
    /// the sets completed in it. A session she opened and never lifted in is
    /// not history and must not be in this list.
    public static func next(_ lift: LiftShape, history: [[DoneSet]], level: Level) -> Target {
        let targetReps = reps(lift, level: level)
        // Cardio is one block of time, not a set count. Everything else keeps
        // the level's count; a plank held three or four times is exactly right.
        let setCount = lift.cardio ? 1 : sets(for: level)

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
            let weight = lift.increment == 0 ? 0 : round(lastWeight * 0.9, to: lift.increment)
            return Target(weight: weight, reps: targetReps, sets: setCount,
                          note: "Backing off 10%. Three tough sessions is a signal, not a failure.")
        }

        // Snap even when holding: a hand-typed 97 should come back as a bar you
        // can actually load, not follow her around forever.
        let held = lift.increment == 0 ? 0 : round(lastWeight, to: lift.increment)
        return Target(weight: held, reps: targetReps, sets: setCount, note: "Same weight. Own it this time.")
    }

    /// "2.5" rather than "2.5000", and "5" rather than "5.0".
    private static func trim(_ n: Double) -> String {
        n == n.rounded() ? String(Int(n)) : String(n)
    }
}
