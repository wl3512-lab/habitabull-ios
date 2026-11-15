//
// the week as workouts.
//
// The rule being protected here is the one that is easy to get wrong and
// impossible to see: lifts belong to the workout's name, not to the weekday.
// Two Mondays called "Push day" are one decision, and an app that keeps two
// copies of it will show her an edit that did not take.

import XCTest
import HabitaBullKit
@testable import HabitaBull

final class PlannerTests: XCTestCase {
    /// A day she takes out of the week keeps what she put on it, and keeps it
    /// after she closes the app. The first fix for this lived in the week
    /// screen's own state, so Monday renamed to "Chest and arms", switched
    /// off, saved and reopened came back as the app's default Push day.
    /// Found by a codex review 2026-11-15.
    func testADayShePutAwayIsStillHersAfterTheAppCloses() {
        var week = Planner.plan(for: [1, 3, 5])
        week.remembered[1] = "Chest and arms"

        let reopened = try! JSONDecoder().decode(Routine.self, from: JSONEncoder().encode(week))

        XCTAssertEqual(reopened.remembered[1], "Chest and arms",
                       "the name she gave Monday did not survive being saved")
    }

    /// And a week saved before the app remembered any of this still opens,
    /// rather than taking her whole routine down with it.
    func testAWeekSavedBeforeThisStillOpens() throws {
        let old = Data("""
        {"days":[{"weekday":1,"label":"Push day"}],"library":{"Push day":["bench-press"]}}
        """.utf8)

        let week = try XCTUnwrap(try? JSONDecoder().decode(Routine.self, from: old),
                                 "a week saved before this would not open at all")

        XCTAssertEqual(week.label(on: 1), "Push day")
        XCTAssertEqual(week.lifts(on: 1), ["bench-press"])
        XCTAssertTrue(week.remembered.isEmpty)
    }

    func testThreeDaysBecomePushPullAndLegs() {
        let week = Planner.plan(for: [1, 3, 5])
        XCTAssertEqual(week.inOrder.map(\.label), ["Push day", "Pull day", "Leg day"])
        XCTAssertEqual(week.inOrder.map(\.weekday), [1, 3, 5])
    }

    func testEveryWorkoutStartsWithLiftsInIt() {
        let week = Planner.plan(for: [1, 3, 5])
        for day in week.days {
            XCTAssertFalse(week.library[day.label]?.isEmpty ?? true,
                           "\(day.label) opened empty")
        }
    }

    func testAddingADayKeepsTheDaysSheAlreadyNamed() {
        var week = Planner.plan(for: [1, 3, 5])
        week.rename("Push day", to: "Chest and arms")
        week.setLifts(["bench-press", "db-curl"], of: "Chest and arms")

        let wider = Planner.plan(for: [1, 3, 5, 6], keeping: week)
        XCTAssertEqual(wider.label(on: 1), "Chest and arms", "her own name was overwritten")
        XCTAssertEqual(wider.library["Chest and arms"], ["bench-press", "db-curl"])
        XCTAssertNotNil(wider.label(on: 6), "the new day got no workout")
    }

    func testDroppingADayLeavesTheWorkoutWhereSheCanGetItBack() {
        var week = Planner.plan(for: [1, 3, 5])
        week.setLifts(["deadlift"], of: "Leg day")
        let narrower = Planner.plan(for: [1, 3], keeping: week)

        XCTAssertNil(narrower.label(on: 5))
        XCTAssertEqual(narrower.library["Leg day"], ["deadlift"],
                       "a workout she edited was thrown away with the day")
    }

    func testTwoDaysWithOneNameAreOneWorkout() {
        // a four day week is upper, lower, upper, lower on purpose
        var week = Planner.plan(for: [1, 2, 4, 5])
        XCTAssertEqual(week.inOrder.map(\.label),
                       ["Upper day", "Lower day", "Upper day", "Lower day"])

        week.setLifts(["pull-up"], of: "Upper day")
        XCTAssertEqual(week.lifts(on: 1), ["pull-up"])
        XCTAssertEqual(week.lifts(on: 4), ["pull-up"], "editing one Upper day missed the other")
    }

    func testRenamingAWorkoutTakesItsLiftsWithIt() {
        var week = Planner.plan(for: [1, 2, 4, 5])
        week.setLifts(["pull-up", "db-row"], of: "Upper day")
        week.rename("Upper day", to: "Back day")

        XCTAssertEqual(week.label(on: 1), "Back day")
        XCTAssertEqual(week.label(on: 4), "Back day", "one of the two days kept the old name")
        XCTAssertEqual(week.library["Back day"], ["pull-up", "db-row"])
        XCTAssertNil(week.library["Upper day"], "the old name was left behind with its lifts")
    }

    func testANameOfNothingIsNotARename() {
        var week = Planner.plan(for: [1])
        week.rename("Full body", to: "   ")
        XCTAssertEqual(week.label(on: 1), "Full body")
    }

    func testAWorkoutNameTheAppHasNeverHeardOfStillOpensWithLifts() {
        XCTAssertFalse(Planner.lifts(for: "Beach day").isEmpty)
    }

    func testNoDaysIsNoWeek() {
        XCTAssertTrue(Planner.plan(for: []).days.isEmpty)
    }

    func testTodayReadsTheWorkoutOffTheRoutine() {
        let week = Planner.plan(for: [1, 3, 5])
        XCTAssertEqual(Planner.today(week, weekday: 3)?.label, "Pull day")
        XCTAssertEqual(Planner.today(week, weekday: 3)?.lifts, week.library["Pull day"])
        XCTAssertNil(Planner.today(week, weekday: 2), "a day off was given a workout")
        XCTAssertNil(Planner.today(nil, weekday: 3))
    }

    // MARK: - the screens that read it

    func testTheHomeScreenCallsTodayWhateverSheCalledIt() {
        var week = Planner.plan(for: [1, 3, 5])
        week.rename("Pull day", to: "Back and biceps")
        let profile = Profile(trainingDays: [1, 3, 5], weekChosen: true, routine: week)

        // a Wednesday
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let wednesday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 11))!

        XCTAssertEqual(Home.shape(profile: profile, today: nil, now: wednesday, calendar: calendar),
                       .plan("Back and biceps"))
    }

    func testAPhoneFromBeforeRoutinesExistedStillNamesTheDay() {
        let profile = Profile(trainingDays: [1, 3, 5], weekChosen: true)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let wednesday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 11))!

        XCTAssertEqual(Home.shape(profile: profile, today: nil, now: wednesday, calendar: calendar),
                       .plan("Leg day"), "the old name is what that phone has always shown")
    }
}
