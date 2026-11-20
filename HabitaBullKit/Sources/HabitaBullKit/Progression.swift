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
    /// The number is help, not load: an assisted pull-up machine counts the
    /// counterweight, so more of it is easier. Everything about progress runs
    /// the other way on one of these, and reading it as an ordinary weighted
    /// lift rewarded a good session with more help and answered a bad
    /// fortnight by taking help away.
    public var assisted: Bool

    public init(increment: Double, compound: Bool = false, heavy: Bool = false, hold: Bool = false,
                cardio: Bool = false, floor: Double = 0, assisted: Bool = false) {
        self.assisted = assisted
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
    /// When the workout began, where the caller knows it.
    ///
    /// The civil day is the right key for attendance and the wrong one for
    /// order: fly west overnight and the workout she did yesterday carries a
    /// later date than the one she did this morning. Optional because the
    /// fixtures ported from the web app have only a day, and they must go on
    /// being read exactly as the web app reads them.
    /// Found by a codex audit 2026-11-18.
    public var startedAt: Date?

    public init(date: String, label: String = "", lifts: [LoggedLift], oneOff: Bool = false,
                startedAt: Date? = nil) {
        self.date = date; self.label = label; self.lifts = lifts; self.oneOff = oneOff
        self.startedAt = startedAt
    }
}

public enum Progression {
    static let baseLoad: [Level: Double] = [.new: 45, .returning: 65, .experienced: 95]
    /// The same three numbers read from the far end, for the machines that
    /// count help. Experience there means needing less of it, and reading
    /// `baseLoad` straight gave an experienced lifter 95 lb of counterweight
    /// on her first assisted pull-up where a novice got 45: the novice was
    /// asked to pull more of herself than the regular.
    /// Found by a codex audit 2026-11-17. The three numbers are a training
    /// judgement rather than a fact, and Lucy's to set.
    static let helpBase: [Level: Double] = [.new: 95, .returning: 65, .experienced: 45]
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

    /// What the app says about a lift it cannot load: the number stays, and
    /// changing it is hers to do. Said in the unit she is counting in.
    private static func said(_ lift: LiftShape) -> String {
        if lift.cardio { return "Same as last time. Change the time or the incline if you want to." }
        if lift.hold { return "Same as last time. Change the time if you want to." }
        return "Same as last time. Change the reps if you want to."
    }

    /// A weight you can actually load. Never below one increment.
    public static func round(_ weight: Double, to increment: Double) -> Double {
        guard increment > 0 else { return 0 }
        return Swift.max(increment, (weight / increment).rounded() * increment)
    }

    /// A loadable amount of help, where none at all is a real answer.
    ///
    /// `round` never returns less than one increment, because a bar with
    /// nothing on it is not a weight. A machine set to no counterweight is
    /// the whole point of the machine, and rounding it up handed 2.5 lb of
    /// help back to someone who had just done the lift unaided and missed
    /// her reps, under the words "Same help".
    /// Found by a codex audit 2026-11-17.
    static func roundHelp(_ weight: Double, to increment: Double) -> Double {
        guard increment > 0 else { return 0 }
        return Swift.max(0, (weight / increment).rounded() * increment)
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
        let base = (lift.assisted ? helpBase[level] : baseLoad[level]) ?? 45
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
        // By the clock when every session carries one, by the day otherwise.
        // All or nothing on purpose: mixing the two orders two sessions by
        // different rules depending on which pair is being compared, which is
        // not an order at all. Found by a codex audit 2026-11-18.
        let byClock = sessions.allSatisfy { $0.startedAt != nil }
        return sessions
            .sorted { byClock ? $0.startedAt! > $1.startedAt! : $0.date > $1.date }
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

        // Her best set of last time. On a bar that is the heaviest; on a
        // machine that counts help it is the lightest, and `max` was reading
        // the set she needed the most help on. Warming up with 45 lb of help
        // and doing the two sets after it at 30 was read as 45, so the plan
        // started from her worst set, and "down 2.5 lb of help" then offered
        // 42.5: still more help than she had finished on. Every assisted case
        // in the tests used one weight for the whole session, so max and min
        // were the same number in all of them and none could see it.
        // Found by a codex audit 2026-11-16.
        let soFar = last.map(\.weight)
        let lastWeight = (lift.assisted ? soFar.min() : soFar.max())
            ?? startingWeight(lift, level: level)

        // A lift the app cannot load keeps the number she last logged.
        //
        // A push-up, a plank and a treadmill have no weight to add, so the
        // only number that could move is the count. The rules used to hold the
        // level's count -- 12 reps, 30 seconds, 20 minutes -- while the line
        // under it said "Add two reps this time", so the app asked for more
        // and planned the same, every session, for ever.
        //
        // Lucy's call, 2026-11-20: "working out is very inconsistent and what
        // if i stay same strength for a while bc im inconsistent in gym? why
        // cant reps stay the same until user logs them different?" So it does.
        // There is no automatic step up, and no sentence asking for one. A
        // session of fewer reps lowers the target by exactly as much, which is
        // the only back-off a lift with no weight on it can have.
        //
        // Her best set of last time, because the target is one number for the
        // whole lift and the best is the one she knows she has in her.
        //
        // Cardio also carries its incline, and nothing else. That field holds
        // a percent rather than a load, so resetting it to flat every session
        // is the other wrong answer: she set 5% on Monday and found 0% on
        // Wednesday.
        if lift.increment == 0 {
            let lastCount = last.map(\.reps).max() ?? targetReps
            return Target(weight: lift.cardio ? lastWeight : 0, reps: lastCount, sets: setCount,
                          note: said(lift))
        }

        let clearedAll = last.count >= setCount && last.allSatisfy { $0.reps >= targetReps }

        // An assisted machine counts help rather than load, so every rule
        // below points the wrong way on one. Clearing the set earned her more
        // counterweight, which is the machine doing more of the pull-up, and
        // three hard sessions took help away from someone already struggling.
        // Found by a codex review 2026-11-15.
        if lift.assisted, lift.increment > 0 {
            if clearedAll {
                // rounded, because the number she typed is not always one the
                // machine has. A typed 31 lb of help less a 2.5 lb increment
                // is 28.5, which is not a setting on any stack; `roundHelp`
                // puts it on 27.5 and leaves zero reachable.
                // Found by a codex audit 2026-11-17.
                let next = roundHelp(lastWeight - lift.increment, to: lift.increment)
                // what it actually came down by, not what the increment is.
                // Rounding 31 lb of help onto the stack gives 27.5, and the
                // line under it said "Down 2.5 lb of help" about a drop of
                // 3.5. Found by a codex audit 2026-11-17.
                let came = lastWeight - next
                return Target(weight: next, reps: targetReps, sets: setCount,
                              // not "that is a pull-up": the other assisted
                              // machine in the library is a dip, and a shape
                              // does not carry a name to tell them apart
                              note: next == 0
                                ? "No help left. That is all you."
                                : "Down \(trim(came)) lb of help. You earned it.")
            }
            let tough = history.prefix(3)
            let short = tough.filter { !($0.isEmpty == false && $0.allSatisfy { $0.reps >= targetReps }) }.count
            if short >= 3 && history.count >= 3 {
                // more help, which is the same mercy as taking weight off a bar
                // both halves rounded: the increment half was raw. More help
                // is the larger of a tenth more and one increment more, and
                // the one that wins is not the one that is loadable: at 21 lb
                // of help the raw increment half won outright and gave 23.5,
                // and at 26 the tenth is larger before rounding and smaller
                // after it (28.6 rounds to 27.5), so the raw 28.5 won there
                // too. The reasoning that the tenth "wins above 25 and is
                // already rounded" was wrong on both counts. One test each.
                let eased = Swift.max(round(lastWeight * 1.1, to: lift.increment),
                                      round(lastWeight + lift.increment, to: lift.increment))
                return Target(weight: eased, reps: targetReps, sets: setCount,
                              note: "More help for now. Three tough sessions is a signal, not a failure.")
            }
            // and when holding it snaps the number, say so. 31 lb of help
            // held at "Same help" came back as 30, and a sentence that says
            // nothing changed over a number that did is the app telling her
            // something untrue about her own training.
            // Found by a codex audit 2026-11-17.
            let same = roundHelp(lastWeight, to: lift.increment)
            return Target(weight: same, reps: targetReps, sets: setCount,
                          note: same == lastWeight
                            ? "Same help. Own it this time."
                            // "rounded to", not "what the machine has": the
                            // increment is what this lift loads in, and
                            // whether the stack in her gym has that setting
                            // is not something the rules know. Said plainly
                            // after a codex audit 2026-11-17 pointed out that
                            // the same sentence on a bar promises a weight
                            // this app's own plate loader cannot build.
                            : "Same help, rounded to \(trim(same)) lb.")
        }

        if clearedAll {
            // the true step, not the increment: a weight she typed does not
            // have to be a multiple of it, and rounding 136 up by 2.5 gives
            // 137.5, which is up by 1.5.
            let weight = round(lastWeight + lift.increment, to: lift.increment)
            return Target(weight: weight, reps: targetReps, sets: setCount,
                          note: "Up \(trim(weight - lastWeight)) lb. You earned it.")
        }

        let recent = history.prefix(3)
        let missed = recent.filter { !($0.isEmpty == false && $0.allSatisfy { $0.reps >= targetReps }) }.count
        if missed >= 3 && history.count >= 3 {
            // every path below here loads in something: a lift that does not
            // was answered above, where the count is the only number there is.
            let cut = max(roundDown(lastWeight * 0.9, to: lift.increment), lift.floor)
            // A lift already at its lightest cannot be backed off. Printing
            // "backing off 10%" over a number that did not move would be the
            // app describing something it did not do, so it says the true
            // thing instead: there is nowhere lighter to go. Reaching this is
            // now the floor's doing and only the floor's, because the cut
            // rounds down and so always has somewhere to go until it does not.
            if cut >= lastWeight {
                return Target(weight: lastWeight, reps: targetReps, sets: setCount,
                              note: "This is as light as it loads. Stay here until it moves.")
            }
            return Target(weight: cut, reps: targetReps, sets: setCount,
                          note: "Backing off 10%. Three tough sessions is a signal, not a failure.")
        }

        // Snap even when holding: a hand-typed 97 should come back as a bar you
        // can actually load, not follow her around forever.
        let held = round(lastWeight, to: lift.increment)
        // and the snap gets said here too: holding 136 lb handed back 135
        // under "Same weight".
        return Target(weight: held, reps: targetReps, sets: setCount,
                      note: held == lastWeight
                        ? "Same weight. Own it this time."
                        : "Same weight, rounded to \(trim(held)) lb.")
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
