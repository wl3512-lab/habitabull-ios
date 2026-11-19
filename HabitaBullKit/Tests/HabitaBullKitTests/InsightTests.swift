//
// what the record is allowed to say about her, and when it has to stay quiet.
//
// All the dates here are real: 2026-10-28, 11-04 and 11-11 are Wednesdays,
// 11-02 and 11-09 are Mondays, 11-05 and 11-12 are Thursdays.

import XCTest
@testable import HabitaBullKit

final class InsightTests: XCTestCase {
    /// The better of two sets at one weight is the one with more reps.
    ///
    /// Public and shared because the day card had its own half of this rule:
    /// it compared weight only, so at 135 for 5 and 135 for 8 the card named
    /// one set as her best of the day and the chart named the other.
    /// Found by a codex audit 2026-11-17.
    func testAtTheSameWeightTheBetterSetIsTheOneWithMoreReps() {
        XCTAssertTrue(Lifts.beats((135, 8), (135, 5), assisted: false))
        XCTAssertFalse(Lifts.beats((135, 5), (135, 8), assisted: false))
        // and heavier still wins whatever the reps say
        XCTAssertTrue(Lifts.beats((140, 1), (135, 8), assisted: false))
    }

    /// On a machine that counts help, less of it is the better set, and the
    /// reps do not turn around with it.
    func testLessHelpIsTheBetterSetAndMoreRepsStillBreakTheTie() {
        XCTAssertTrue(Lifts.beats((20, 5), (30, 5), assisted: true))
        XCTAssertTrue(Lifts.beats((30, 8), (30, 5), assisted: true))
        XCTAssertFalse(Lifts.beats((30, 5), (20, 8), assisted: true))
    }

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

    /// A machine that counts help draws the same line upside down.
    ///
    /// The day's point was the set with the biggest number, which on an
    /// assisted pull-up is the set she needed the most help on. So the chart
    /// of the lift she is working hardest at showed her worst set of each
    /// day, and the day she warmed up with a lot of help read as her best.
    /// Found by a codex audit 2026-11-16.
    func testOnAnAssistedLiftTheDaysPointIsTheLeastHelpSheNeeded() {
        let day = session("2026-11-04", [(45, 8, true), (30, 8, true), (30, 8, true)],
                          id: "assisted-pull-up")
        let track = Lifts.track([day], "assisted-pull-up", assisted: true)
        XCTAssertEqual(track.first?.weight, 30,
                       "the chart printed the set she needed the most help on")
    }

    func testTwoSessionsInOneDayOnAnAssistedLiftGiveTheLighterOfThem() {
        let track = Lifts.track([session("2026-11-04", [(45, 5, true)], id: "assisted-pull-up"),
                                 session("2026-11-04", [(30, 5, true)], id: "assisted-pull-up")],
                                "assisted-pull-up", assisted: true)
        XCTAssertEqual(track.count, 1)
        XCTAssertEqual(track.first?.weight, 30)
    }

    /// Left out, nothing changes. Every other case in this class relies on
    /// that, and so does every caller that does not know about help.
    func testWithoutTheFlagBiggerIsStillBetter() {
        let day = session("2026-11-04", [(45, 8, true), (30, 8, true)])
        XCTAssertEqual(Lifts.track([day], "back-squat").first?.weight, 45)
    }

    /// One rule for whether a line is counted in reps.
    ///
    /// The chart worked it out and the card beside it worked it out again,
    /// and on an assisted lift they disagreed: a history all at zero help
    /// drew a line in reps under a figure reading "0 lb", and the first day
    /// she went back to a little help switched the chart's units without
    /// saying so. Found by a codex audit 2026-11-17.
    func testALiftWithNoLoadOnItIsCountedInReps() {
        let pushUps = [LiftPoint(date: "2026-11-01", weight: 0, reps: 8),
                       LiftPoint(date: "2026-11-03", weight: 0, reps: 12)]
        XCTAssertTrue(Lifts.countedInReps(pushUps, assisted: false))
    }

    func testNoHelpLeftIsNotALiftWithNoLoadOnIt() {
        let unaided = [LiftPoint(date: "2026-11-01", weight: 0, reps: 3),
                       LiftPoint(date: "2026-11-03", weight: 0, reps: 5)]
        XCTAssertFalse(Lifts.countedInReps(unaided, assisted: true),
                       "a lift she needs no help for was drawn in reps under a card still "
                       + "reading 0 lb")
    }

    func testOneLoadedDayIsEnoughToCountInPounds() {
        let mixed = [LiftPoint(date: "2026-11-01", weight: 0, reps: 8),
                     LiftPoint(date: "2026-11-03", weight: 45, reps: 5)]
        XCTAssertFalse(Lifts.countedInReps(mixed, assisted: false))
    }

    /// The headline and the chart under it count in the same unit.
    ///
    /// The headline used to ask whether the LAST point carried a weight,
    /// which is a different question from the one the chart asks, and a
    /// loaded lift whose most recent day happened to be at zero printed
    /// "5 reps" over a line drawn in pounds. Found by a codex audit
    /// 2026-11-17.
    func testTheHeadlineAndTheChartNeverDisagreeAboutUnits() {
        let dropped = [LiftPoint(date: "2026-11-01", weight: 45, reps: 8),
                       LiftPoint(date: "2026-11-03", weight: 0, reps: 5)]
        XCTAssertFalse(Lifts.countedInReps(dropped, assisted: false))
        XCTAssertEqual(Lifts.headline(dropped, assisted: false), "0 lb",
                       "the headline counted in reps under a line drawn in pounds")

        let pushUps = [LiftPoint(date: "2026-11-01", weight: 0, reps: 8),
                       LiftPoint(date: "2026-11-03", weight: 0, reps: 12)]
        XCTAssertEqual(Lifts.headline(pushUps, assisted: false), "12 reps")
        XCTAssertEqual(Lifts.gain(pushUps, assisted: false), "+4")

        let unaided = [LiftPoint(date: "2026-11-01", weight: 10, reps: 5),
                       LiftPoint(date: "2026-11-03", weight: 0, reps: 5)]
        XCTAssertEqual(Lifts.headline(unaided, assisted: true), "0 lb",
                       "no help left is a reading, not the absence of one")
        XCTAssertEqual(Lifts.gain(unaided, assisted: true), "+10",
                       "ten pounds less help is ten pounds of progress")
    }

    func testOneRepReadsAsOneRep() {
        let one = [LiftPoint(date: "2026-11-01", weight: 0, reps: 1)]
        XCTAssertEqual(Lifts.headline(one, assisted: false), "1 rep")
    }

    func testNothingGainedSaysNothing() {
        let flat = [LiftPoint(date: "2026-11-01", weight: 135, reps: 5),
                    LiftPoint(date: "2026-11-03", weight: 135, reps: 5)]
        XCTAssertNil(Lifts.gain(flat, assisted: false))
        let worse = [LiftPoint(date: "2026-11-01", weight: 135, reps: 5),
                     LiftPoint(date: "2026-11-03", weight: 125, reps: 5)]
        XCTAssertNil(Lifts.gain(worse, assisted: false), "a deload is not a telling-off")
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
