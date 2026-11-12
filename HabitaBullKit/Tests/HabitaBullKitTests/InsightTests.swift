//
// what the record is allowed to say about her, and when it has to stay quiet.
//
// All the dates here are real: 2026-10-28, 11-04 and 11-11 are Wednesdays,
// 11-02 and 11-09 are Mondays, 11-05 and 11-12 are Thursdays.

import XCTest
@testable import HabitaBullKit

final class InsightTests: XCTestCase {
    private func went(_ dates: [String]) -> [SessionRecord] {
        dates.map { SessionRecord(date: $0, completed: true, loggedSet: true) }
    }

    func testItSaysNothingUntilThereIsEnoughToSay() {
        // three Wednesdays in a row is a run, not yet a habit
        let history = went(["2026-10-28", "2026-11-04", "2026-11-11"])
        XCTAssertNil(Insight.reliableWeekday(history))
    }

    func testItSaysNothingWhenNoDayStandsOut() {
        // six days, spread, nothing with three on it
        let history = went(["2026-11-02", "2026-11-04", "2026-11-05",
                            "2026-11-09", "2026-11-10", "2026-11-12"])
        XCTAssertNil(Insight.reliableWeekday(history))
    }

    func testItNamesTheDaySheKeepsTurningUpOn() {
        let history = went(["2026-10-28", "2026-11-04", "2026-11-11",
                            "2026-11-02", "2026-11-05", "2026-11-10"])
        let said = Insight.reliableWeekday(history)
        XCTAssertEqual(said?.weekday, 3, "Wednesday is index 3 with Sunday at 0")
        XCTAssertEqual(said?.days, 3)
    }

    func testTwoWorkoutsOnOneDayAreOneDayOfTurningUp() {
        // the same Wednesday twice cannot buy a pattern
        let doubled = went(["2026-11-11", "2026-11-11", "2026-11-04",
                            "2026-11-02", "2026-11-05", "2026-11-10"])
        XCTAssertNil(Insight.reliableWeekday(doubled), "two sessions in a day is one day")
    }

    func testADaySheOnlyPlannedDoesNotCount() {
        var planned = went(["2026-10-28", "2026-11-04", "2026-11-02",
                            "2026-11-05", "2026-11-10", "2026-11-12"])
        planned.append(SessionRecord(date: "2026-11-11", completed: false, loggedSet: false))
        XCTAssertNil(Insight.reliableWeekday(planned))
    }

    func testATieGoesToTheEarlierWeekdaySoTheHeadlineHoldsStill() {
        // three Mondays, three Wednesdays
        let history = went(["2026-11-02", "2026-11-09", "2026-11-16",
                            "2026-10-28", "2026-11-04", "2026-11-11"])
        XCTAssertEqual(Insight.reliableWeekday(history)?.weekday, 1, "Monday, every time")
    }

    func testNothingAtAllSaysNothing() {
        XCTAssertNil(Insight.reliableWeekday([]))
        XCTAssertEqual(Insight.daysByWeekday([]), [0, 0, 0, 0, 0, 0, 0])
    }
}

final class LiftTrackTests: XCTestCase {
    private func session(_ date: String, _ sets: [(Double, Int, Bool)],
                         id: String = "back-squat") -> TrainingSession {
        TrainingSession(date: date, label: "Leg day",
                        lifts: [LoggedLift(exerciseId: id,
                                           sets: sets.map { LoggedSet(weight: $0.0, reps: $0.1, done: $0.2) })])
    }

    func testOneDayIsOnePointAndItIsTheHeaviestSet() {
        let track = Lifts.track([session("2026-11-04", [(135, 8, true), (155, 5, true), (145, 6, true)])],
                                "back-squat")
        XCTAssertEqual(track.count, 1, "three working sets are one answer, not three")
        XCTAssertEqual(track.first?.weight, 155)
        XCTAssertEqual(track.first?.reps, 5)
    }

    func testTheLineReadsOldestFirstWhateverOrderItIsHanded() {
        let track = Lifts.track([session("2026-11-11", [(165, 5, true)]),
                                 session("2026-10-28", [(145, 5, true)]),
                                 session("2026-11-04", [(155, 5, true)])],
                                "back-squat")
        XCTAssertEqual(track.map(\.date), ["2026-10-28", "2026-11-04", "2026-11-11"])
        XCTAssertEqual(track.map(\.weight), [145, 155, 165])
    }

    func testASetSheDidNotDoIsNotOnTheLine() {
        let track = Lifts.track([session("2026-11-04", [(155, 5, true), (185, 1, false)])],
                                "back-squat")
        XCTAssertEqual(track.first?.weight, 155, "the set she racked and left is not a lift")
    }

    func testADayWithNothingDoneIsNotADayOnTheLine() {
        let track = Lifts.track([session("2026-11-04", [(155, 5, false)])], "back-squat")
        XCTAssertTrue(track.isEmpty)
    }

    func testTwoSessionsInOneDayGiveTheHeavierOfThem() {
        let track = Lifts.track([session("2026-11-04", [(155, 5, true)]),
                                 session("2026-11-04", [(175, 3, true)])],
                                "back-squat")
        XCTAssertEqual(track.count, 1)
        XCTAssertEqual(track.first?.weight, 175)
    }

    func testAtTheSameWeightMoreRepsIsTheBetterSet() {
        let track = Lifts.track([session("2026-11-04", [(155, 5, true), (155, 8, true)])],
                                "back-squat")
        XCTAssertEqual(track.first?.reps, 8)
    }

    func testAnotherLiftOnTheSameDayIsNotOnThisLine() {
        let mixed = TrainingSession(date: "2026-11-04", label: "Leg day", lifts: [
            LoggedLift(exerciseId: "back-squat", sets: [LoggedSet(weight: 155, reps: 5, done: true)]),
            LoggedLift(exerciseId: "deadlift", sets: [LoggedSet(weight: 255, reps: 5, done: true)]),
        ])
        XCTAssertEqual(Lifts.track([mixed], "back-squat").first?.weight, 155)
        XCTAssertEqual(Lifts.track([mixed], "deadlift").first?.weight, 255)
        XCTAssertTrue(Lifts.track([mixed], "bench-press").isEmpty)
    }
}
