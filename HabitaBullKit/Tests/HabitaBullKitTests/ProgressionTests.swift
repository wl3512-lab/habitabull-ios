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

    func testTheLastOfTheHelpIsAPullUp() {
        let target = Progression.next(assistedPullUp, history: [did(3, 8, 2.5)], level: .new)
        XCTAssertEqual(target.weight, 0)
        XCTAssertEqual(target.note, "No help left. That is a pull-up.")
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
        XCTAssertFalse(Progression.next(plank, history: [did(4, 30, 0)], level: .experienced)
            .note.lowercased().contains("reps"))
        XCTAssertFalse(Progression.next(bike, history: [did(1, 20, 0)], level: .experienced)
            .note.lowercased().contains("reps"))
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
