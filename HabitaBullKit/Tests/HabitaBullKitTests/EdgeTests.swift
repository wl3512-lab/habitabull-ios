//
// The corners the fixtures never reach.
//
// A review on 2026-11-06 went through the package branch by branch and named
// the ones no generated case touches, along with four inputs that crashed
// rather than answered. Each of those is a test here, so the next person to
// change a rule finds out from a test rather than from a phone.

import XCTest
@testable import HabitaBullKit

private let utc = TimeZone(identifier: "UTC")!

final class EdgeTests: XCTestCase {
    let squat = LiftShape(increment: 2.5, compound: true)
    let plank = LiftShape(increment: 0, hold: true)

    // a small catalogue, enough to reach the branches
    let catalogue = [
        Lift(id: "back-squat", name: "Back Squat", equipment: "barbell", primary: "quads", increment: 2.5, compound: true),
        Lift(id: "treadmill", name: "Treadmill", equipment: "machine", primary: "quads", increment: 0, compound: false, cardio: true),
        Lift(id: "outdoor-run", name: "Outdoor Run", equipment: "bodyweight", primary: "quads", increment: 0, compound: false, cardio: true),
        Lift(id: "ab-crunch-machine", name: "Ab Crunch Machine", equipment: "machine", primary: "core", increment: 2.5, compound: false),
        Lift(id: "bench-press", name: "Bench Press", equipment: "barbell", primary: "chest", increment: 2.5, compound: true),
        Lift(id: "lat-pulldown", name: "Lat Pulldown", equipment: "machine", primary: "back", increment: 2.5, compound: true),
    ]

    // MARK: - what used to crash

    func testAStoredWeekWithAnOddVariantDoesNotBringTheAppDown() {
        let week = Planner.generate(level: .new, days: [1], equipment: ["barbell"],
                                    dayTypes: ["full-body"], variants: [1: -1], catalogue: catalogue)
        XCTAssertEqual(week.count, 1)
        // -1 lands on the last shape, the way any other index would wrap
        XCTAssertEqual(week[0].label, "Full body B")
    }

    func testAskingForNoDaysIsNoDaysRatherThanATrap() {
        XCTAssertEqual(Schedule.spread([1, 2, 3], count: 0), [])
        XCTAssertEqual(Schedule.spread([1, 2, 3], count: -1), [])
    }

    func testAWeekdayOutsideTheWeekIsBroughtBackIntoIt() {
        // -3 reads as Thursday, so Friday is tomorrow and Monday is named
        XCTAssertEqual(Schedule.nextTrainingDay([5], todayWeekday: -3), "tomorrow")
        XCTAssertEqual(Schedule.nextTrainingDay([1], todayWeekday: -3), "Monday")
        XCTAssertEqual(Schedule.nextTrainingDay([4], todayWeekday: 9), "Thursday")   // 9 reads as Tuesday
    }

    func testANonsenseIncrementPrintsOddlyRatherThanTrapping() {
        let silly = LiftShape(increment: 1e30, compound: true)
        let note = Progression.next(silly, history: [Array(repeating: DoneSet(weight: 100, reps: 99), count: 3)], level: .new).note
        XCTAssertTrue(note.hasPrefix("Up "), note)
    }

    func testAMonthOutsideTheYearIsNothingRatherThanADifferentMonth() {
        // the web's months are 0-11 and these are 1-12, so a line-for-line
        // port would ask for month 0 and quietly get December of last year
        XCTAssertEqual(Attendance.monthMatrix(year: 2026, month: 0, sessions: [], today: "2026-11-06", zone: utc), [])
        XCTAssertEqual(Attendance.monthMatrix(year: 2026, month: 13, sessions: [], today: "2026-11-06", zone: utc), [])
    }

    // MARK: - branches no fixture reaches

    func testACardioDayFallsBackToTheLiftThatNeedsNoKit() {
        // kettlebells only: neither named cardio lift is in her kit, so the
        // last one wins because it is the one that needs nothing
        let week = Planner.generate(level: .new, days: [2], equipment: ["kettlebell"],
                                    dayTypes: ["cardio"], catalogue: catalogue)
        XCTAssertEqual(week.first?.exercises.map(\.exerciseId), ["outdoor-run"])
        XCTAssertEqual(week.first?.exercises.first?.sets, 1)
    }

    func testFebruaryInALeapYear() {
        let grid = Attendance.monthMatrix(year: 2028, month: 2, sessions: [], today: "2026-11-06", zone: utc)
        XCTAssertEqual(grid.flatMap { $0 }.compactMap(\.date).last, "2028-02-29")
        XCTAssertEqual(grid.flatMap { $0 }.compactMap(\.day).count, 29)
    }

    func testAWholePoundIncrementReadsWithoutADecimalPoint() {
        let fiver = LiftShape(increment: 5, compound: true)
        let note = Progression.next(fiver, history: [Array(repeating: DoneSet(weight: 100, reps: 99), count: 3)], level: .new).note
        XCTAssertEqual(note, "Up 5 lb. You earned it.")
    }

    func testAWeekWithTooMuchRuledOutComesBackShortRatherThanWrong() {
        let a = Availability(days: [], avoid: [0, 1, 2, 3, 4], count: 4)
        XCTAssertEqual(Schedule.planWeek(a), [5, 6])
    }

    func testASessionWithNothingLoggedInItIsNotHistory() {
        // reachable only from a caller that builds history by hand
        let t = Progression.next(squat, history: [[]], level: .new)
        XCTAssertEqual(t.weight, Progression.startingWeight(squat, level: .new))
    }

    func testADayTypeThisVersionHasNeverHeardOfFallsBackToFullBody() {
        XCTAssertEqual(DayTypes.named("bogus").id, "full-body")
        let week = Planner.generate(level: .new, days: [1], equipment: ["barbell", "machine"],
                                    dayTypes: ["bogus"], catalogue: catalogue)
        XCTAssertEqual(week.first?.dayType, "full-body")
    }

    func testANameStopsAtThreeThingsBeyondTheDayType() {
        let lifts = ["back-squat", "ab-crunch-machine", "bench-press", "lat-pulldown"]
            .map { PlannedLift(exerciseId: $0, sets: 3, reps: 8, weight: 100) }
        let off = DayFit.offType("cardio", exercises: lifts, catalogue: catalogue)
        XCTAssertEqual(off.count, 4)
        XCTAssertEqual(DayFit.mixedName("cardio", offIds: off, catalogue: catalogue),
                       "Cardio, legs, abs and chest")
    }

    func testAskingAboutADayThatIsNotInTheWeek() {
        let week = [PlannedDay(day: 1, label: "Leg day", dayType: "legs", exercises: [])]
        XCTAssertEqual(DayFit.sameWorkoutDays(week, at: 7), [])
        XCTAssertEqual(DayFit.shareLineup(week, from: 7), week)
    }

    // MARK: - the one place this deliberately differs from v1

    func testAnExactSplitAnswersTheSameWayEveryTime() {
        // the web lets whichever anchor it saw first win, which is the order
        // her sessions happen to sit in. This picks the earlier slot instead,
        // so the same history always gives the same answer
        let evenings = Attendance.self   // (keeps the line short)
        _ = evenings
        let a = Schedule.observedAnchor(completedHours: [20, 20, 20, 7, 7, 7])
        let b = Schedule.observedAnchor(completedHours: [7, 7, 7, 20, 20, 20])
        XCTAssertEqual(a?.anchor, .wake)
        XCTAssertEqual(b?.anchor, .wake)
        XCTAssertEqual(a?.count, 3)
        XCTAssertEqual(a?.total, 6)
    }

    // MARK: - the step the whole port depends on

    func testHistoryIsNewestFirstDoneOnlyAndNeverEmpty() {
        let sessions = [
            TrainingSession(date: "2026-10-01", lifts: [
                .init(exerciseId: "back-squat", sets: [.init(weight: 95, reps: 5, done: true)])]),
            TrainingSession(date: "2026-11-01", lifts: [
                .init(exerciseId: "back-squat", sets: [
                    .init(weight: 105, reps: 5, done: true),
                    .init(weight: 115, reps: 5, done: false)])]),
            // opened and never lifted in: not history
            TrainingSession(date: "2026-11-05", lifts: [
                .init(exerciseId: "back-squat", sets: [.init(weight: 120, reps: 5, done: false)])]),
            TrainingSession(date: "2026-09-01", lifts: [
                .init(exerciseId: "bench-press", sets: [.init(weight: 80, reps: 5, done: true)])]),
        ]
        let history = Progression.history(of: "back-squat", in: sessions)
        XCTAssertEqual(history.map { $0.map(\.weight) }, [[105], [95]])

        // and it is the shape `next` expects, so the two fit together
        XCTAssertEqual(Progression.next(squat, history: history, level: .new).weight, 105)
    }

    func testHistoryIsOrderedByDateNotByHowStorageHappensToHoldIt() {
        let sessions = [
            TrainingSession(date: "2026-11-01", lifts: [
                .init(exerciseId: "plank", sets: [.init(weight: 0, reps: 45, done: true)])]),
            TrainingSession(date: "2026-11-03", lifts: [
                .init(exerciseId: "plank", sets: [.init(weight: 0, reps: 60, done: true)])]),
        ].reversed().map { $0 }   // stored out of order on purpose
        XCTAssertEqual(Progression.history(of: "plank", in: sessions).first?.first?.reps, 60)
    }
}
