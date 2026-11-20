//
// The web app's own progression tests, ported case for case. They describe
// behaviour Lucy has already proved in a gym over a year, which is exactly
// what a rewrite is most likely to lose.
//
// Source: lib/engine.test.ts in ~/Desktop/habitabull, describe("nextTarget")
// and describe("startingWeight").

import XCTest
@testable import HabitaBullKit

final class ProgressionTests: XCTestCase {
    // the real library's numbers for the lifts the web tests use
    let squat = LiftShape(increment: 2.5, compound: true)
    let bench = LiftShape(increment: 2.5, compound: true)
    let curl = LiftShape(increment: 2.5)
    let pushUp = LiftShape(increment: 0, compound: true)
    let plank = LiftShape(increment: 0, hold: true)
    let bike = LiftShape(increment: 0, cardio: true)
    let deadlift = LiftShape(increment: 2.5, compound: true, heavy: true)
    /// The counterweight on an assisted pull-up machine. The number is help,
    /// so every rule about it runs the other way.
    let assistedPullUp = LiftShape(increment: 2.5, compound: true, assisted: true)

    /// One session of `count` sets at the same weight and reps, as history.
    func did(_ count: Int, _ reps: Int, _ weight: Double) -> [DoneSet] {
        Array(repeating: DoneSet(weight: weight, reps: reps), count: count)
    }

    // MARK: - starting weight

    func testAnAccessoryStartsLighterThanACompound() {
        XCTAssertLessThan(Progression.startingWeight(curl, level: .new),
                          Progression.startingWeight(squat, level: .new))
    }

    func testBodyweightMovementsCarryNoLoad() {
        XCTAssertEqual(Progression.startingWeight(pushUp, level: .experienced), 0)
    }

    func testAnExperiencedLifterStartsHeavier() {
        XCTAssertGreaterThan(Progression.startingWeight(squat, level: .experienced),
                             Progression.startingWeight(squat, level: .new))
    }

    // MARK: - a machine that counts help rather than load
    //
    // These ran through the ordinary weighted path, which rewarded a good
    // session with more counterweight and answered three bad ones by taking
    // help away. Both backwards, and the second one is backwards at the
    // moment someone is already struggling.
    // Found by a codex review 2026-11-15.

    func testClearingAnAssistedLiftTakesHelpAway() {
        let target = Progression.next(assistedPullUp, history: [did(3, 8, 45)], level: .new)
        XCTAssertEqual(target.weight, 42.5, "it gave her more help for clearing the set")
        XCTAssertEqual(target.note, "Down 2.5 lb of help. You earned it.")
    }

    func testTheLastOfTheHelpIsTheWholeLift() {
        let target = Progression.next(assistedPullUp, history: [did(3, 8, 2.5)], level: .new)
        XCTAssertEqual(target.weight, 0)
        // it used to say "That is a pull-up", and the other assisted machine
        // in the library is a dip. A LiftShape carries no name, so the line
        // cannot know which one it is talking to and should not guess.
        XCTAssertEqual(target.note, "No help left. That is all you.")
    }

    /// The first session on a machine that counts help.
    ///
    /// `startingWeight` reads `baseLoad` for a bar and `helpBase` for one of
    /// these, and the two run opposite ways: the experienced lifter needs the
    /// LEAST help and the beginner the most. Before the fix both read
    /// `baseLoad`, so a first-timer was offered 45 lb of counterweight on a
    /// pull-up she cannot do at all, and someone nearly doing one unaided was
    /// offered 95. Nothing caught it, because every assisted case in this
    /// class hands `next` a history and never asks about the first day.
    /// Found by a codex audit 2026-11-17.
    func testAFirstAssistedSessionGivesTheBeginnerTheMostHelp() {
        let beginner = Progression.startingWeight(assistedPullUp, level: .new)
        let strong = Progression.startingWeight(assistedPullUp, level: .experienced)
        XCTAssertGreaterThan(beginner, strong,
                             "the beginner was offered less help than the experienced lifter, "
                             + "which is what load numbers read off a bar look like on a "
                             + "machine that counts help")
        XCTAssertEqual(beginner, 95)
        XCTAssertEqual(strong, 45)
        // and the same through `next`, which is how the app asks
        XCTAssertEqual(Progression.next(assistedPullUp, history: [], level: .new).weight, 95)
    }

    /// No help left, and short of the reps.
    ///
    /// `round` never returns less than one increment, because a bar with
    /// nothing on it is not a weight. A machine set to no counterweight is
    /// the whole point of the machine, and rounding it up handed 2.5 lb of
    /// help back to someone who had just done the lift unaided, under the
    /// words "Same help". `roundHelp` was written for this and the case it
    /// was written for had no test. Found by a codex audit 2026-11-17.
    func testMissingRepsWithNoHelpLeavesHerWithNone() {
        let target = Progression.next(assistedPullUp, history: [did(3, 5, 0)], level: .new)
        XCTAssertEqual(target.weight, 0,
                       "it gave 2.5 lb of help back to someone doing the lift unaided and "
                       + "called it \"Same help\"")
        XCTAssertEqual(target.note, "Same help. Own it this time.")
    }

    /// Help she can actually set on the machine.
    ///
    /// Nothing stops her typing a weight the stack does not have, and the
    /// plan built on it was raw arithmetic: 31 lb of help less a 2.5 lb
    /// increment is 28.5, and there is no pin for that. Both directions, so
    /// the easing branch cannot drift back. Found by a codex audit 2026-11-17.
    func testHelpComesBackOnASettingTheMachineHas() {
        let cleared = Progression.next(assistedPullUp, history: [did(3, 8, 31)], level: .new)
        XCTAssertEqual(cleared.weight.truncatingRemainder(dividingBy: 2.5), 0,
                       "\(cleared.weight) lb of help is not a setting on the stack")
        XCTAssertEqual(cleared.weight, 27.5)

        // 21, not 31, and the number matters. More help is the larger of "a
        // tenth more" and "one increment more", and under 25 lb the increment
        // is the larger of the two. That was the half that was never rounded,
        // so this is the case it showed in. The other half is covered below.
        let hard = did(3, 4, 21)
        let eased = Progression.next(assistedPullUp, history: [hard, hard, hard], level: .new)
        XCTAssertEqual(eased.weight.truncatingRemainder(dividingBy: 2.5), 0,
                       "\(eased.weight) lb of help is not a setting on the stack")
        XCTAssertGreaterThan(eased.weight, 21, "three tough sessions and it did not ease up")
    }

    /// More help off the tenth is a setting the machine has too.
    ///
    /// The fix for the above rounded both halves, and the comment on it said
    /// the tenth "was already rounded", so only the increment half could go
    /// wrong. That is not true, and a codex audit said so: a tenth more than
    /// 26 lb is 28.6, which rounds down to 27.5, which means the unrounded
    /// increment half, 28.5, was the larger of the two and won. She was asked
    /// for 28.5 lb of help on a stack that moves in 2.5s.
    func testMoreHelpOffATenthIsAlsoASettingTheMachineHas() {
        let hard = did(3, 4, 26)
        let eased = Progression.next(assistedPullUp, history: [hard, hard, hard], level: .new)
        XCTAssertEqual(eased.weight.truncatingRemainder(dividingBy: 2.5), 0,
                       "\(eased.weight) lb of help is not a setting on the stack")
        XCTAssertGreaterThan(eased.weight, 26, "three tough sessions and it did not ease up")
    }

    /// Holding a weight the machine cannot set says what it did instead.
    ///
    /// "Same help" over a number that moved is the app telling her something
    /// untrue about her own training: 31 lb of help held came back as 30.
    /// Found by a codex audit 2026-11-17.
    func testHoldingHelpTheMachineCannotSetSaysSo() {
        // two sessions, so it is neither a clear nor three tough ones
        let some = did(3, 5, 31)
        let held = Progression.next(assistedPullUp, history: [some, some], level: .new)
        XCTAssertEqual(held.weight, 30)
        XCTAssertEqual(held.note, "Same help, rounded to 30 lb.",
                       "the number changed and the line did not say so")

        let onTheStack = did(3, 5, 30)
        let same = Progression.next(assistedPullUp, history: [onTheStack, onTheStack], level: .new)
        XCTAssertEqual(same.weight, 30)
        XCTAssertEqual(same.note, "Same help. Own it this time.",
                       "nothing moved, so there is nothing to explain")
    }

    /// And the same on a bar: a typed 136 lb held comes back as 135.
    func testHoldingAWeightTheBarCannotLoadSaysSo() {
        let some = did(3, 5, 136)
        let held = Progression.next(squat, history: [some, some], level: .new)
        XCTAssertEqual(held.weight, 135)
        // word for word, and not "what the bar loads": this app's own plate
        // loader moves in 5 lb steps, so a 2.5 lb snap is not something the
        // bar can be promised. Named by a codex audit 2026-11-17.
        XCTAssertEqual(held.note, "Same weight, rounded to 135 lb.",
                       "the number changed and the line did not say so")

        let loadable = did(3, 5, 135)
        let same = Progression.next(squat, history: [loadable, loadable], level: .new)
        XCTAssertEqual(same.note, "Same weight. Own it this time.")
    }

    /// A lift described to the planner keeps what kind of number it carries.
    ///
    /// The app plans through `Exercise.shape`, which has carried this since
    /// the assisted fixes went in. The kit's own `Lift` did not, so anything
    /// planning through the package dropped it on the way to the shape and
    /// treated a counterweight as a load. Dormant, and a test is the only
    /// thing that will keep it dormant. Found by a codex audit 2026-11-17.
    func testALiftsShapeCarriesWhetherItsNumberIsHelp() {
        let machine = Lift(id: "assisted-pull-up", name: "Assisted Pull-Up", equipment: "machine",
                           primary: "back", increment: 2.5, compound: true, assisted: true)
        XCTAssertTrue(machine.shape.assisted,
                      "the planner's lift dropped its assisted flag on the way to its shape, "
                      + "so a counterweight would be planned as though it were a load")
        XCTAssertEqual(Progression.startingWeight(machine.shape, level: .experienced), 45)

        let bar = Lift(id: "back-squat", name: "Back Squat", equipment: "barbell",
                       primary: "legs", increment: 2.5, compound: true)
        XCTAssertFalse(bar.shape.assisted)
    }

    /// A lift saved before today still reads.
    ///
    /// `Lift` is public and `Codable`, and `assisted` was added to it as a
    /// plain `Bool`. A synthesised decoder requires every non-optional key
    /// whatever the initialiser's defaults say, so everything encoded before
    /// this morning would have thrown `keyNotFound`. Found by a codex audit
    /// 2026-11-17.
    func testALiftEncodedBeforeTodayStillDecodes() throws {
        // only the keys a lift has always had. The first version of this test
        // spelled out heavy, hold and cardio too, so it would have gone on
        // passing if those three stopped being optional: four keys are
        // lenient here and the test only covered one of them.
        let old = Data(#"""
        {"id":"back-squat","name":"Back Squat","equipment":"barbell","primary":"legs",
         "increment":2.5,"compound":true}
        """#.utf8)
        let lift = try JSONDecoder().decode(Lift.self, from: old)
        XCTAssertEqual(lift.id, "back-squat")
        XCTAssertFalse(lift.assisted, "a lift with nothing to say about help is not assisted")

        // and a round trip of a new one keeps it
        let machine = Lift(id: "assisted-pull-up", name: "Assisted Pull-Up", equipment: "machine",
                           primary: "back", increment: 2.5, compound: true, assisted: true)
        let back = try JSONDecoder().decode(Lift.self, from: JSONEncoder().encode(machine))
        XCTAssertTrue(back.assisted)
    }

    /// The line under the number says what the number did.
    ///
    /// Rounding the plan onto the stack made the note wrong: 31 lb of help
    /// comes down to 27.5, and "Down 2.5 lb of help" is a sentence about a
    /// drop of 3.5. The bar had the same fault from the same cause.
    /// Found by a codex audit 2026-11-17.
    func testTheNoteSaysWhatTheWeightActuallyDid() {
        let help = Progression.next(assistedPullUp, history: [did(3, 8, 31)], level: .new)
        XCTAssertEqual(help.weight, 27.5)
        XCTAssertEqual(help.note, "Down 3.5 lb of help. You earned it.")

        let bar = Progression.next(squat, history: [did(3, 8, 136)], level: .new)
        XCTAssertEqual(bar.weight, 137.5)
        XCTAssertEqual(bar.note, "Up 1.5 lb. You earned it.")

        // and a weight that was already on the stack is unchanged, which is
        // every case the parity fixtures cover
        let clean = Progression.next(squat, history: [did(3, 8, 135)], level: .new)
        XCTAssertEqual(clean.note, "Up 2.5 lb. You earned it.")
    }

    func testHelpNeverGoesBelowNothing() {
        let target = Progression.next(assistedPullUp, history: [did(3, 8, 0)], level: .new)
        XCTAssertEqual(target.weight, 0, "an unassisted pull-up cannot be helped less than not at all")
    }

    func testThreeHardSessionsOnAnAssistedLiftGiveMoreHelp() {
        let hard = did(3, 4, 45)
        let target = Progression.next(assistedPullUp, history: [hard, hard, hard], level: .new)
        XCTAssertGreaterThan(target.weight, 45,
                             "it took help away from someone who missed three sessions running")
        XCTAssertEqual(target.note, "More help for now. Three tough sessions is a signal, not a failure.")
    }

    func testMissingRepsOnAnAssistedLiftHoldsTheHelpWhereItIs() {
        let target = Progression.next(assistedPullUp, history: [did(3, 5, 45)], level: .new)
        XCTAssertEqual(target.weight, 45)
        XCTAssertEqual(target.note, "Same help. Own it this time.")
    }

    /// Her session, not the hardest set in it.
    ///
    /// `lastWeight` was `last.map(\.weight).max()`, which is her heaviest set
    /// on a bar and the set she needed the most help on, on a machine that
    /// counts help. Warming up with 45 lb of help and settling at 30 for the
    /// two sets after it was read as 45, so "down 2.5 lb of help" offered
    /// 42.5: more help than she had just finished on, every session, forever.
    ///
    /// Every assisted case above uses one weight for the whole session, so
    /// max and min are the same number in all of them and none of them could
    /// see this. Found by a codex audit 2026-11-16.
    func testAnAssistedLiftIsPlannedFromHerBestSetAndNotHerWorst() {
        let eased = [DoneSet(weight: 45, reps: 8),
                     DoneSet(weight: 30, reps: 8),
                     DoneSet(weight: 30, reps: 8)]
        let target = Progression.next(assistedPullUp, history: [eased], level: .new)
        XCTAssertEqual(target.weight, 27.5,
                       "it planned from the 45 lb of help she warmed up with instead of the "
                       + "30 she finished on")
    }

    /// And the other way is untouched, which is the half of this that could
    /// break quietly: a warm-up set must never become the working weight.
    func testAWeightedLiftIsStillPlannedFromHerHeaviestSet() {
        let built = [DoneSet(weight: 95, reps: 8),
                     DoneSet(weight: 135, reps: 8),
                     DoneSet(weight: 135, reps: 8)]
        let target = Progression.next(squat, history: [built], level: .new)
        XCTAssertEqual(target.weight, 137.5, "a warm-up set became the working weight")
    }

    // MARK: - what to lift next

    func testStartsAtTheLevelBaselineWithNoHistory() {
        let t = Progression.next(squat, history: [], level: .new)
        XCTAssertEqual(t.weight, Progression.startingWeight(squat, level: .new))
        XCTAssertTrue(t.note.lowercased().contains("first time"))
    }

    func testAddsExactlyOneIncrementAfterClearingEveryRep() {
        let t = Progression.next(squat, history: [did(3, 10, 100)], level: .new)
        XCTAssertEqual(t.weight, 102.5)
    }

    func testHoldsTheWeightAfterAMissedSession() {
        let t = Progression.next(squat, history: [did(3, 7, 100)], level: .new)
        XCTAssertEqual(t.weight, 100)
        XCTAssertTrue(t.note.lowercased().contains("same weight"))
    }

    func testDeloadsTenPercentAfterThreeConsecutiveMisses() {
        let t = Progression.next(squat, history: [did(3, 6, 100), did(3, 6, 100), did(3, 6, 100)], level: .new)
        XCTAssertEqual(t.weight, 90)
        XCTAssertTrue(t.note.lowercased().contains("backing off"))
    }

    func testDoesNotDeloadOnOnlyTwoMisses() {
        let t = Progression.next(squat, history: [did(3, 6, 100), did(3, 6, 100)], level: .new)
        XCTAssertEqual(t.weight, 100)
    }

    func testBodyweightLiftsStayAtZeroAndAskForRepsInstead() {
        let t = Progression.next(pushUp, history: [did(3, 12, 0)], level: .new)
        XCTAssertEqual(t.weight, 0)
        XCTAssertTrue(t.note.lowercased().contains("reps"))
    }

    func testAlwaysLandsOnALoadableWeight() {
        // 2.5 lb is the smallest real jump: 1.25 lb plates, one per side
        let t = Progression.next(bench, history: [did(3, 3, 97)], level: .new)
        XCTAssertEqual(t.weight.truncatingRemainder(dividingBy: 2.5), 0, accuracy: 0.0001)
    }

    func testAnUnloadableLiftIsNeverToldToAddWeight() {
        // the sentence itself, not a word it must avoid. Prohibiting only
        // "reps" was satisfied by "Add 5 lb this time." on a plank, which is
        // exactly the instruction this test is named after.
        // Found by a codex audit 2026-11-17.
        let held = Progression.next(plank, history: [did(4, 30, 0)], level: .experienced)
        XCTAssertEqual(held.note, "Same as last time. Change the time if you want to.")
        // a bike is answered before any of this: the field holds an incline
        // she set herself, so the rules leave both numbers where they are
        let ridden = Progression.next(bike, history: [did(1, 20, 0)], level: .experienced)
        XCTAssertEqual(ridden.note, "Same as last time. Change the time or the incline if you want to.")
        for note in [held.note, ridden.note] {
            XCTAssertFalse(note.lowercased().contains("reps"), note)
            XCTAssertFalse(note.lowercased().contains("lb"),
                           "a lift with no weight on it cannot be told to add any: \(note)")
        }
    }


    // MARK: - a lift the app cannot load stays where she left it

    /// Lucy's call, 2026-11-20: no automatic step up on anything counted in
    /// reps, seconds or minutes. "why cant reps stay the same until user logs
    /// them different?"
    func testTheCountIsWhatSheLastLogged() {
        // twelve push-ups, where the level would have asked for eight
        let after12 = Progression.next(pushUp, history: [did(3, 12, 0)], level: .new)
        XCTAssertEqual(after12.reps, 12, "it went back to the level's count")
        XCTAssertEqual(after12.weight, 0)
        // and a 45 second plank, where the level would have asked for 30
        let after45 = Progression.next(plank, history: [did(3, 45, 0)], level: .new)
        XCTAssertEqual(after45.reps, 45)
        // and 35 minutes on the bike, where the level would have asked for 20,
        // with the incline she set still on it
        let after35 = Progression.next(bike, history: [[DoneSet(weight: 5, reps: 35)]],
                                       level: .new)
        XCTAssertEqual(after35.reps, 35)
        XCTAssertEqual(after35.weight, 5, "it dropped the incline she set")
    }

    func testAWeekSheWasWeakerLowersTheCountWithHer() {
        // the whole point of her asking: a bad week is not a failed rep
        // target, and the app follows her down as readily as up
        let t = Progression.next(pushUp, history: [did(3, 6, 0), did(3, 12, 0)], level: .new)
        XCTAssertEqual(t.reps, 6)
    }

    func testNothingUnloadableIsEverAskedForMore() {
        for t in [Progression.next(pushUp, history: [did(3, 12, 0)], level: .new),
                  Progression.next(plank, history: [did(3, 45, 0)], level: .new),
                  Progression.next(bike, history: [did(1, 35, 0)], level: .new)] {
            for word in ["add", "longer", "more", "lb"] {
                XCTAssertFalse(t.note.lowercased().contains(word),
                               "the count does not move on its own: \(t.note)")
            }
        }
    }

    /// The first session still comes from the level, because there is nothing
    /// of hers to carry yet.
    func testTheFirstTimeStillComesFromTheLevel() {
        XCTAssertEqual(Progression.next(pushUp, history: [], level: .new).reps, 8)
        XCTAssertEqual(Progression.next(plank, history: [], level: .new).reps, 30)
        XCTAssertEqual(Progression.next(bike, history: [], level: .new).reps, 20)
    }

    // MARK: - sets and reps

    func testCardioIsOneBlockAndAHoldIsNot() {
        XCTAssertEqual(Progression.next(bike, history: [], level: .experienced).sets, 1)
        XCTAssertEqual(Progression.next(plank, history: [], level: .experienced).sets,
                       Progression.sets(for: .experienced))
    }

    func testCardioKeepsTheInclineItWasLeftAt() {
        // the weight field holds a percent for cardio, and she set it herself
        let t = Progression.next(bike, history: [did(1, 25, 5)], level: .new)
        XCTAssertEqual(t.weight, 5)
    }

    func testAHoldIsCountedInSecondsAndCardioInMinutes() {
        XCTAssertEqual(Progression.reps(plank, level: .new), 30)
        XCTAssertEqual(Progression.reps(bike, level: .new), 20)
    }

    func testAHeavyLiftIsNeverPrescribedForTen() {
        XCTAssertLessThanOrEqual(Progression.reps(deadlift, level: .new), 5)
    }

    func testAnAccessoryGetsFourMoreRepsThanACompound() {
        XCTAssertEqual(Progression.reps(curl, level: .new), Progression.reps(squat, level: .new) + 4)
    }

    // MARK: - clearing what she actually planned

    func testALiftSettledBelowTheLevelsSetCountStillProgresses() {
        // she does two sets of curls, not three, and clears every rep of both
        let curl = LiftShape(increment: 2.5)
        let twoGoodSets = [[DoneSet(weight: 25, reps: 12), DoneSet(weight: 25, reps: 12)]]

        // judged against the level's three, two cleared sets read as a miss
        let byTheLevel = Progression.next(curl, history: twoGoodSets, level: .new)
        XCTAssertEqual(byTheLevel.weight, 25, "the level's count is still the default")

        // judged against the two she planned, she cleared it
        let byWhatShePlanned = Progression.next(curl, history: twoGoodSets, level: .new, planned: 2)
        XCTAssertEqual(byWhatShePlanned.weight, 27.5)
        XCTAssertEqual(byWhatShePlanned.sets, 2, "it plans the number she actually does")
        XCTAssertEqual(byWhatShePlanned.note, "Up 2.5 lb. You earned it.")
    }

    func testPlanningMoreSetsThanSheDidIsStillAMiss() {
        let curl = LiftShape(increment: 2.5)
        let twoGoodSets = [[DoneSet(weight: 25, reps: 12), DoneSet(weight: 25, reps: 12)]]
        let asked = Progression.next(curl, history: twoGoodSets, level: .new, planned: 4)
        XCTAssertEqual(asked.weight, 25, "two of four is not every set")
    }

    func testAPlannedCountOfNothingIsNotTakenLiterally() {
        let curl = LiftShape(increment: 2.5)
        let one = [[DoneSet(weight: 25, reps: 12)]]
        XCTAssertEqual(Progression.next(curl, history: one, level: .new, planned: 0).sets, 1)
        XCTAssertEqual(Progression.next(curl, history: one, level: .new, planned: -3).sets, 1)
    }

    // MARK: - the back-off has a bottom
    //
    // The floorless cut is the older of the two defects in
    // ux-tests/2026-09-26-habitabull-longitudinal-test.md: a compliant lifter
    // walked from a 45 lb deadlift to 17.5 lb in six weeks, because 10% off
    // 10% off 10% has no bottom and the old rounding stopped at one increment.
    // These pin the bottom.

    func testABarbellLiftIsNeverCutBelowTheEmptyBar() {
        let bar = LiftShape(increment: 2.5, compound: true, floor: 45)
        let hard = [did(3, 6, 47.5), did(3, 6, 47.5), did(3, 6, 47.5)]
        XCTAssertEqual(Progression.next(bar, history: hard, level: .new).weight, 45)
    }

    func testAnEmptyBarCannotBeBackedOffAndTheAppSaysSo() {
        let bar = LiftShape(increment: 2.5, compound: true, floor: 45)
        let t = Progression.next(bar, history: [did(3, 6, 45), did(3, 6, 45), did(3, 6, 45)], level: .new)
        XCTAssertEqual(t.weight, 45, "there is nothing under an empty bar")
        XCTAssertFalse(t.note.lowercased().contains("backing off"),
                       "the number did not move, so the app must not claim it cut")
        XCTAssertTrue(t.note.lowercased().contains("as light as it loads"))
    }

    func testTheFloorNeverPutsWeightBackOn() {
        // Typed in by hand under the bar, which the gym cannot do but the
        // keypad can. The cut must not become a promotion.
        let bar = LiftShape(increment: 2.5, compound: true, floor: 45)
        let t = Progression.next(bar, history: [did(3, 6, 30), did(3, 6, 30), did(3, 6, 30)], level: .new)
        XCTAssertEqual(t.weight, 30)
    }

    func testSixWeeksOfHardSessionsStopAtTheBarRatherThanWalkingPastIt() {
        let bar = LiftShape(increment: 2.5, compound: true, floor: 45)
        var weight = 200.0
        for _ in 0..<20 {
            let hard = Array(repeating: did(3, 6, weight), count: 3)
            weight = Progression.next(bar, history: hard, level: .new).weight
            XCTAssertGreaterThanOrEqual(weight, 45, "a squat you cannot load is not a squat")
        }
        XCTAssertEqual(weight, 45)
    }

    func testADumbbellStopsAtTheLightestPairNotAtTheIncrement() {
        let db = LiftShape(increment: 2.5, floor: 5)
        let t = Progression.next(db, history: [did(3, 10, 5), did(3, 10, 5), did(3, 10, 5)], level: .new)
        XCTAssertEqual(t.weight, 5, "2.5 lb dumbbells are not a thing")
    }

    func testBodyweightIsUnaffectedByTheFloor() {
        let t = Progression.next(pushUp, history: [did(3, 6, 0), did(3, 6, 0), did(3, 6, 0)], level: .new)
        XCTAssertEqual(t.weight, 0)
    }

    func testABackOffAlwaysBacksOff() {
        // 10% off 12.5 lb is 11.25, which is nearer 12.5 than 10, so rounding
        // to the nearest loadable weight left her exactly where she was while
        // the app announced a cut. Found by an independent review, 2026-11-10.
        let db = LiftShape(increment: 2.5, floor: 5)
        let stuck = [did(3, 10, 12.5), did(3, 10, 12.5), did(3, 10, 12.5)]
        let t = Progression.next(db, history: stuck, level: .new)
        XCTAssertEqual(t.weight, 10, "10, 7.5 and 5 are all on the rack")
        XCTAssertTrue(t.note.lowercased().contains("backing off"))
    }

    func testEveryKindOfEquipmentKnowsHowLightItGoes() {
        XCTAssertEqual(LiftShape.floor(for: "barbell"), 45)
        XCTAssertEqual(LiftShape.floor(for: "Barbell"), 45, "the library's spelling should not decide")
        XCTAssertEqual(LiftShape.floor(for: "dumbbell"), 5)
        XCTAssertEqual(LiftShape.floor(for: "kettlebell"), 10)
        XCTAssertEqual(LiftShape.floor(for: "machine"), 10)
        XCTAssertEqual(LiftShape.floor(for: "bodyweight"), 0)
        XCTAssertEqual(LiftShape.floor(for: "sandbag"), 0, "an unknown kit gets no floor, not a guess")
    }
}
