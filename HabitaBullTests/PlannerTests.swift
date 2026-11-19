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
    // MARK: - filling a day from its kind

    /// A day filled from its kind is filled out of the real catalogue.
    ///
    /// The app answered this from a switch over six names, so every day it
    /// did not recognise got the same three lifts. The rules package has had
    /// the muscle slots and the picker since the port, and nothing called
    /// them. Found while wiring the week, 2026-11-18.
    func testADayIsFilledFromItsKindAndNotFromItsName() {
        let push = Planner.lifts(forKind: "push")
        XCTAssertEqual(push.count, 3, "a day should start with three lifts, whatever kind it is")
        XCTAssertEqual(Set(push).count, 3, "the same lift was picked twice")

        // asked of the rules themselves: nothing on it is off a push day
        let planned = push.map { PlannedLift(exerciseId: $0, sets: 3, reps: 8, weight: 0) }
        XCTAssertEqual(DayFit.offType("push", exercises: planned,
                                      catalogue: ExerciseLibrary.asLifts), [],
                       "a push day was filled with work that is not push work")
    }

    /// Two kinds of day are two different days.
    func testADayOfADifferentKindIsFilledDifferently() {
        XCTAssertNotEqual(Planner.lifts(forKind: "legs"), Planner.lifts(forKind: "push"),
                          "every kind of day was filled the same way")
    }

    /// Nothing that cannot be logged is ever planned.
    ///
    /// Cardio and timed holds have no screen yet, so a picker that could put
    /// one on her week would be planning a day the log screen cannot take.
    func testADayIsNeverFilledWithSomethingTheAppCannotLog() {
        for kind in DayTypes.all.map(\.id) {
            for id in Planner.lifts(forKind: kind) {
                let lift = ExerciseLibrary.find(id)
                XCTAssertNotNil(lift, "\(kind) was filled with a lift the library does not have: \(id)")
                XCTAssertFalse(lift?.cardio ?? false, "\(kind) was filled with cardio: \(id)")
                XCTAssertFalse(lift?.hold ?? false, "\(kind) was filled with a timed hold: \(id)")
            }
        }
    }

    // MARK: - what kind of day it is

    /// A week saved before the app had a word for it still answers.
    ///
    /// The kind of day drives what fills it and what it gets called when it
    /// grows past itself, so every name has to resolve to one. Reading it off
    /// the name is how a routine written last week keeps working.
    func testAWeekSavedBeforeDayKindsExistedStillKnowsWhatItIs() {
        let week = Routine(days: [Routine.Day(weekday: 1, label: "Push day"),
                                  Routine.Day(weekday: 3, label: "Legs and abs"),
                                  Routine.Day(weekday: 5, label: "Lower day")],
                           library: [:])
        XCTAssertEqual(week.type(of: "Push day"), "push")
        XCTAssertEqual(week.type(of: "Legs and abs"), "legs",
                       "a name of her own that still says legs is still a leg day")
        XCTAssertEqual(week.type(of: "Lower day"), "lower")
        XCTAssertEqual(week.type(of: "Chest and arms"), "full-body",
                       "a name the app cannot read should fall back, not throw")
    }

    /// What she chose beats what the name reads like.
    func testTheKindSheChoseIsTheKindItIs() {
        var week = Routine(days: [Routine.Day(weekday: 1, label: "Leg day")], library: [:])
        week.setType("cardio", of: "Leg day")
        XCTAssertEqual(week.type(of: "Leg day"), "cardio",
                       "the name was read instead of the answer she gave")
    }

    /// Renaming a workout carries its kind with it.
    ///
    /// Without this the kind is left behind under a name nothing answers to,
    /// so the day she just named goes back to being read off its new name:
    /// "Chest and arms" becomes a full body day, and what fills it changes
    /// under her.
    func testRenamingAWorkoutCarriesItsKind() {
        var week = Routine(days: [Routine.Day(weekday: 1, label: "Push day")],
                           library: ["Push day": ["bench-press"]])
        week.setType("push", of: "Push day")

        week.save(["bench-press", "db-curl"], of: "Push day", renamedTo: "Chest and arms")

        XCTAssertEqual(week.type(of: "Chest and arms"), "push",
                       "the kind of day was left behind by the rename")
    }

    /// Saving a day writes the kind she picked on it.
    func testSavingADayWritesTheKindShePicked() {
        var week = Routine(days: [Routine.Day(weekday: 1, label: "Full body")],
                           library: ["Full body": ["back-squat"]])

        week.save(["back-squat"], of: "Full body", renamedTo: "Full body", kind: "legs")

        XCTAssertEqual(week.type(of: "Full body"), "legs")
    }

    /// A routine saved with kinds on it opens with them.
    func testTheKindsSurviveBeingSavedAndRead() throws {
        var week = Routine(days: [Routine.Day(weekday: 1, label: "Push day")],
                           library: ["Push day": ["bench-press"]])
        week.setType("upper", of: "Push day")

        let read = try JSONDecoder().decode(Routine.self, from: JSONEncoder().encode(week))

        XCTAssertEqual(read.type(of: "Push day"), "upper")
    }

    /// The lifts she just built are the ones that survive a merge.
    ///
    /// Editing Push day and renaming it Pull day gave her two Pull days
    /// holding the old Pull day lifts, with the list she had just built gone
    /// and nothing said about it. Found by a codex audit 2026-11-15.
    func testRenamingOntoAnExistingWorkoutKeepsTheListSheJustEdited() {
        var week = Routine(days: [Routine.Day(weekday: 1, label: "Push day"),
                                  Routine.Day(weekday: 4, label: "Pull day")],
                           library: ["Push day": ["bench-press"],
                                     "Pull day": ["barbell-row"]])

        week.save(["bench-press", "overhead-press", "db-curl"], of: "Push day", renamedTo: "Pull day")

        XCTAssertEqual(week.library["Pull day"], ["bench-press", "overhead-press", "db-curl"],
                       "the list she had just built was thrown away by the merge")
        XCTAssertNil(week.library["Push day"])
        XCTAssertEqual(week.label(on: 1), "Pull day")
        XCTAssertEqual(week.label(on: 4), "Pull day")
    }

    /// And saving a day without renaming it still writes where it should.
    // MARK: - what she trained carries back onto the day

    /// The lift she added at the rack is still there next week.
    ///
    /// The plan is where a session's lifts come from, so without this the day
    /// rebuilds from its original shape every week and the swap she made is
    /// forgotten. The rules package has carried the rule since the port and
    /// nothing in the app called it. Found by a codex audit 2026-11-18.
    func testTheLiftSheAddedAtTheRackIsStillThereNextWeek() {
        let week = Routine(days: [Routine.Day(weekday: 3, label: "Leg day")],
                           library: ["Leg day": ["back-squat", "leg-press"]])

        let kept = Planner.remembering(trained("Leg day", ["back-squat", "lying-leg-curl"]),
                                       in: week)

        XCTAssertEqual(kept?.library["Leg day"], ["back-squat", "lying-leg-curl"],
                       "the lift she swapped in was forgotten by the next session")
    }

    /// Only which lifts travel. Nothing else about the week moves.
    func testTrainingADayTheWayItIsPlannedChangesNothing() {
        let week = Routine(days: [Routine.Day(weekday: 3, label: "Leg day")],
                           library: ["Leg day": ["back-squat", "leg-press"]])
        XCTAssertNil(Planner.remembering(trained("Leg day", ["back-squat", "leg-press"]), in: week),
                     "a day she trained as planned should not be written back at all")
    }

    /// A quick workout is not a decision about the day it fell on.
    func testAQuickWorkoutLeavesTheDayAlone() {
        let week = Routine(days: [Routine.Day(weekday: 3, label: "Leg day")],
                           library: ["Leg day": ["back-squat", "leg-press"]])
        XCTAssertNil(Planner.remembering(trained("Quick workout", ["db-curl"]), in: week))
    }

    /// And a name her week does not use is not a workout of hers to rewrite.
    func testAWorkoutHerWeekHasNeverHeardOfIsNotAddedToIt() {
        let week = Routine(days: [Routine.Day(weekday: 3, label: "Leg day")],
                           library: ["Leg day": ["back-squat", "leg-press"]])
        XCTAssertNil(Planner.remembering(trained("Arms day", ["db-curl"]), in: week),
                     "one improvised day added a workout to her week")
    }

    /// An empty one never blanks a day.
    func testAWorkoutWithNothingInItNeverEmptiesTheDay() {
        let week = Routine(days: [Routine.Day(weekday: 3, label: "Leg day")],
                           library: ["Leg day": ["back-squat", "leg-press"]])
        XCTAssertNil(Planner.remembering(trained("Leg day", []), in: week))
    }

    /// One finished workout, by name, holding the lifts given.
    private func trained(_ label: String, _ lifts: [String]) -> Session {
        Session(id: UUID().uuidString, date: "2026-11-18", label: label,
                exercises: lifts.map {
                    LoggedExercise(exerciseId: $0,
                                   sets: [LoggedSet(weight: 95, reps: 8, done: true)])
                },
                startedAt: .now)
    }

    func testSavingADayWithoutRenamingItKeepsItsName() {
        var week = Routine(days: [Routine.Day(weekday: 1, label: "Push day")],
                           library: ["Push day": ["bench-press"]])

        week.save(["bench-press", "db-curl"], of: "Push day", renamedTo: "  ")

        XCTAssertEqual(week.library["Push day"], ["bench-press", "db-curl"])
        XCTAssertEqual(week.label(on: 1), "Push day")
    }

    /// A rename follows the days she has switched off, the same as the ones
    /// she has not.
    ///
    /// Monday and Thursday sharing Upper day, Thursday switched off and
    /// Monday renamed, left Thursday pointing at a name nothing answers to
    /// any more: turning it back on gave her the old name with default lifts,
    /// which is her workout quietly thrown away. Found by a codex review
    /// 2026-11-15.
    func testRenamingAWorkoutFollowsADayShePutAway() {
        var week = Routine(days: [Routine.Day(weekday: 1, label: "Upper day")],
                           library: ["Upper day": ["bench-press", "barbell-row"]],
                           remembered: [4: "Upper day"])

        week.rename("Upper day", to: "Chest and arms")

        XCTAssertEqual(week.remembered[4], "Chest and arms",
                       "Thursday still points at a workout that no longer exists")
        XCTAssertEqual(week.library["Chest and arms"], ["bench-press", "barbell-row"],
                       "the lifts did not move with the name")
        XCTAssertNil(week.library["Upper day"])
    }

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
