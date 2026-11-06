//
// the rules, without a screen in front of them. these run in under a second,
// which is the point: the web version's bugs were all in rules like these and
// the only way to see one was to stand in a gym and hit it.
//
// every test writes to its own temporary file, so nothing here can touch a
// workout on a real phone or leave anything behind.

import XCTest
@testable import HabitaBull

final class SessionStoreTests: XCTestCase {
    private var file: URL!
    private var store: SessionStore!

    override func setUp() {
        file = URL.temporaryDirectory.appending(path: "sessions-\(UUID().uuidString).json")
        store = SessionStore(fileURL: file)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: file)
    }

    // MARK: - how many sets a lift comes back with

    func testSetCountComesBackFromTheLastTimeYouDidIt() {
        store.startWorkout()
        store.addLift("hammer-curl", sets: 4)
        let curl = indexOf("hammer-curl")
        for _ in 0..<4 { store.logSet(onExercise: curl, weight: 25, reps: 12) }
        store.finishWorkout()

        XCTAssertEqual(store.setsLastTime(of: "hammer-curl"), 4)
    }

    func testASetYouDidNotFinishIsNotASetYouDid() {
        store.startWorkout()
        store.addLift("hammer-curl", sets: 4)
        let curl = indexOf("hammer-curl")
        store.logSet(onExercise: curl, weight: 25, reps: 12)
        store.logSet(onExercise: curl, weight: 25, reps: 12)
        store.finishWorkout()

        // she planned four and did two. two is what she did
        XCTAssertEqual(store.setsLastTime(of: "hammer-curl"), 2)
    }

    func testALiftYouHaveNeverDoneHasNoCountToRemember() {
        XCTAssertNil(store.setsLastTime(of: "hammer-curl"))
        store.startWorkout()
        store.addLift("hammer-curl", sets: 3)
        // opened and never logged: still nothing to remember
        XCTAssertNil(store.setsLastTime(of: "hammer-curl"))
    }

    // MARK: - where the workout goes next

    func testTheNextSetIsTheFirstOneLeftAnywhere() {
        store.startWorkout()
        guard let session = store.today else { return XCTFail("no workout") }
        XCTAssertEqual(session.nextSet?.exercise, 0)

        // finish the first lift and it moves on
        for _ in 0..<session.exercises[0].sets.count {
            store.logSet(onExercise: 0, weight: 95, reps: 8)
        }
        XCTAssertEqual(store.today?.nextSet?.exercise, 1)
    }

    func testALiftAddedAtTheEndDoesNotEndTheWorkout() {
        // the bug she reported twice: a lift added mid-workout is appended, so
        // anything reading position instead of work left calls it the last one
        store.startWorkout()
        store.addLift("hammer-curl", sets: 1)
        let curl = indexOf("hammer-curl")
        let outcome = store.logSet(onExercise: curl, weight: 25, reps: 12)

        XCTAssertEqual(store.today?.nextSet?.exercise, 0, "it should go back to the lift still to do")
        XCTAssertEqual(outcome?.resting, true, "a rest follows, because the workout is not over")
    }

    func testTheWorkoutIsOverOnlyWhenEverySetIsLogged() {
        store.startWorkout()
        guard let session = store.today else { return XCTFail("no workout") }
        for (e, exercise) in session.exercises.enumerated() {
            for _ in exercise.sets { store.logSet(onExercise: e, weight: 95, reps: 8) }
        }
        XCTAssertNil(store.today?.nextSet)
        XCTAssertEqual(store.today?.exercises.last.map { _ in true }, true)
    }

    // MARK: - what logging a set means

    func testTheFirstSetOfALiftIsNeverCalledABest() {
        store.startWorkout()
        XCTAssertEqual(store.logSet(onExercise: 0, weight: 95, reps: 8)?.kind, .first)
    }

    func testABestNeedsANumberToBeat() {
        store.startWorkout()
        _ = store.logSet(onExercise: 0, weight: 95, reps: 8)        // first
        XCTAssertEqual(store.logSet(onExercise: 0, weight: 95, reps: 8)?.kind, .routine,
                       "the same weight again is not a record")
        XCTAssertEqual(store.logSet(onExercise: 0, weight: 100, reps: 8)?.kind, .best)
    }

    func testARecordCountsFromTheMomentItHappens() {
        store.startWorkout()
        _ = store.logSet(onExercise: 0, weight: 95, reps: 8)
        _ = store.logSet(onExercise: 0, weight: 100, reps: 8)       // the new best
        store.addSet(toExercise: 0)
        // the same weight one set later is not a second record
        XCTAssertEqual(store.logSet(onExercise: 0, weight: 100, reps: 8)?.kind, .routine)
    }

    func testWhatYouJustDidBecomesThePlanForTheSetsLeft() {
        store.startWorkout()
        _ = store.logSet(onExercise: 0, weight: 85, reps: 6)        // dropped down
        let left = store.today?.exercises[0].sets.filter { !$0.done } ?? []
        XCTAssertTrue(left.allSatisfy { $0.weight == 85 && $0.reps == 6 },
                      "the sets left should start where the last one ended")
    }

    // MARK: - the set count is a plan, a logged set is a fact

    func testASetYouHaveLoggedCannotBeDropped() {
        store.startWorkout()
        let planned = store.today?.exercises[0].sets.count ?? 0
        for _ in 0..<planned { store.logSet(onExercise: 0, weight: 95, reps: 8) }
        store.dropSet(fromExercise: 0)
        XCTAssertEqual(store.today?.exercises[0].sets.count, planned, "a logged set is not a plan")
    }

    func testOneMoreSetCopiesTheLastOne() {
        store.startWorkout()
        _ = store.logSet(onExercise: 0, weight: 105, reps: 5)
        store.addSet(toExercise: 0)
        XCTAssertEqual(store.today?.exercises[0].sets.last?.weight, 105)
        XCTAssertEqual(store.today?.exercises[0].sets.last?.reps, 5)
    }

    func testAWorkoutWithNothingInItIsNotFinished() {
        store.startWorkout()
        store.finishWorkout()
        XCTAssertNil(store.today?.completedAt, "a workout you walked away from was not completed")
    }

    // MARK: -

    private func indexOf(_ id: String) -> Int {
        store.today?.exercises.firstIndex { $0.exerciseId == id } ?? -1
    }
}
