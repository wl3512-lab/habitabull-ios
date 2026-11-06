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
}
