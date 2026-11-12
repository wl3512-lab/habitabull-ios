//
// the goal, and the one thing about it that is easy to get wrong: how far
// along it reads on the day it is set.

import XCTest
@testable import HabitaBullKit

final class GoalTests: XCTestCase {
    private func session(_ date: String, _ id: String, _ weights: [Double],
                         done: Bool = true) -> TrainingSession {
        TrainingSession(date: date, label: "Leg day",
                        lifts: [LoggedLift(exerciseId: id,
                                           sets: weights.map { LoggedSet(weight: $0, reps: 8, done: done) })])
    }

    private func goal(_ target: Double) -> Goal {
        Goal(exerciseId: "back-squat", targetWeight: target, targetDate: "2026-12-10")
    }

    func testAGoalSetTodayReadsAsNothingDoneYet() {
        // already squatting 150, aiming for 200. the distance is 50 lb and she
        // has covered none of it, which is not 75%.
        let history = [session("2026-11-01", "back-squat", [135, 150])]
        XCTAssertEqual(Goals.progress(history, goal(200)), 0)
    }

    func testHalfTheDistanceReadsAsHalf() {
        let history = [session("2026-11-01", "back-squat", [150]),
                       session("2026-11-08", "back-squat", [175])]
        XCTAssertEqual(Goals.progress(history, goal(200)), 50)
    }

    func testReachingItReadsAsAHundredAndStaysThere() {
        let history = [session("2026-11-01", "back-squat", [150]),
                       session("2026-11-08", "back-squat", [205])]
        XCTAssertEqual(Goals.progress(history, goal(200)), 100)
        XCTAssertTrue(Goals.met(history, goal(200)))
    }

    func testAGoalBelowWhereSheStartedIsAlreadyMetOrIsNotADistance() {
        let history = [session("2026-11-01", "back-squat", [150])]
        XCTAssertEqual(Goals.progress(history, goal(135)), 100, "she is already past it")
        XCTAssertEqual(Goals.progress([], goal(135)), 0, "no history is not a finished goal")
    }

    func testOnlyFinishedSetsCount() {
        let planned = [session("2026-11-01", "back-squat", [150], done: false)]
        XCTAssertEqual(Goals.best(planned, "back-squat"), 0,
                       "a set she did not lift is not a set she lifted")
    }

    func testTheStartIsTheOldestSessionWhateverOrderTheyArrive() {
        let forwards = [session("2026-11-01", "back-squat", [150]),
                        session("2026-11-08", "back-squat", [175])]
        XCTAssertEqual(Goals.start(forwards, "back-squat"), 150)
        XCTAssertEqual(Goals.start(forwards.reversed(), "back-squat"), 150,
                       "the package must not assume the caller's order")
    }

    func testAnotherLiftsHistoryIsNotThisLiftsHistory() {
        let history = [session("2026-11-01", "leg-press", [300])]
        XCTAssertEqual(Goals.best(history, "back-squat"), 0)
        XCTAssertEqual(Goals.progress(history, goal(200)), 0)
    }

    func testTheDaysLeftAreWholeDaysAndGoNegativeOnceItIsPast() {
        let cal = Attendance.calendar()
        let today = Attendance.date("2026-12-01", cal)!
        XCTAssertEqual(Goals.daysLeft(goal(200), from: today, cal), 9)
        let past = Attendance.date("2026-12-20", cal)!
        XCTAssertEqual(Goals.daysLeft(goal(200), from: past, cal), -10)
    }
}

// MARK: - where a goal starts from

extension GoalTests {
    func testAGoalSetTodayOpensAtNothingEvenAfterYearsOfTraining() {
        // she opened at 100, is at 150 now, and wants 200. the distance she
        // set out to cover is 150 to 200, not 100 to 200: a goal that opens
        // at 50% done is congratulating her for last year.
        let history = [
            session("2026-01-05", "back-squat", [100]),
            session("2026-11-09", "back-squat", [150]),
        ]
        let goal = Goal(exerciseId: "back-squat", targetWeight: 200,
                        targetDate: "2027-01-01", startWeight: 150)
        XCTAssertEqual(Goals.progress(history, goal), 0)

        let halfway = history + [session("2026-11-11", "back-squat", [175])]
        XCTAssertEqual(Goals.progress(halfway, goal), 50)
    }

    func testAGoalSavedBeforeBaselinesExistedStillReads() {
        let history = [
            session("2026-01-05", "back-squat", [100]),
            session("2026-11-09", "back-squat", [150]),
        ]
        let old = Goal(exerciseId: "back-squat", targetWeight: 200, targetDate: "2027-01-01")
        XCTAssertNil(old.startWeight)
        XCTAssertEqual(Goals.progress(history, old), 50,
                       "an old goal should keep reading the way it always did")
        XCTAssertEqual(Goals.baseline(history, old), 100)
    }
}
