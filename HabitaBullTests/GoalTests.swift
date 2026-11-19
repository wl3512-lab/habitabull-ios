//
// the goal, on the app's side of the line.
//
// The arithmetic is the package's and is tested there. What is tested here is
// that the goal reaches the disk and comes back, that a phone which saved a
// profile before goals existed still opens, and that the plan on Today says
// the weight rather than only the shape.

import XCTest
import HabitaBullKit
@testable import HabitaBull

final class GoalTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!

    override func setUp() {
        super.setUp()
        suite = "goal-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testAGoalSurvivesTheAppClosing() {
        let store = ProfileStore(defaults: defaults)
        store.save(Profile(name: "Lucy", trainingDays: [1, 3, 5], weekChosen: true))
        store.update {
            // with the weight she started from, which is the field the bar on
            // screen is drawn against. Saving a goal without one left this
            // test green while every real goal came back at nothing.
            // Found by a codex audit 2026-11-18.
            $0.goal = Goal(exerciseId: "back-squat", targetWeight: 185,
                           targetDate: "2026-12-30", startWeight: 135)
        }

        let later = ProfileStore(defaults: defaults)
        XCTAssertEqual(later.profile?.goal?.exerciseId, "back-squat")
        XCTAssertEqual(later.profile?.goal?.targetWeight, 185)
        XCTAssertEqual(later.profile?.goal?.targetDate, "2026-12-30")
        XCTAssertEqual(later.profile?.goal?.startWeight, 135,
                       "the goal came back without the weight it started from, so the bar "
                       + "under it is drawn from the wrong end")
        XCTAssertEqual(later.profile?.name, "Lucy", "setting a goal rewrote the rest of her")

        // and the number she would actually see
        let history = [TrainingSession(
            date: "2026-11-01", lifts: [LoggedLift(exerciseId: "back-squat",
                                                   sets: [HabitaBullKit.LoggedSet(weight: 160, reps: 5, done: true)])])]
        XCTAssertEqual(Goals.progress(history, later.profile!.goal!), 50,
                       "halfway from 135 to 185 is not reading as halfway")
    }

    /// Saving a goal she already had does not move where it started from.
    ///
    /// A goal saved before baselines were written down has none, and the bar
    /// is drawn from the oldest session in her history. Saving wrote today's
    /// best in instead, so opening a goal at 50 percent, changing only its
    /// date and pressing Save put it back to 0 percent. Pressing Save without
    /// changing anything did it too.
    /// Found by a codex audit 2026-11-18.
    func testSavingAGoalSheAlreadyHasKeepsWhereItStarted() {
        let history = [
            TrainingSession(date: "2026-09-01",
                            lifts: [LoggedLift(exerciseId: "back-squat",
                                               sets: [HabitaBullKit.LoggedSet(weight: 100, reps: 5, done: true)])]),
            TrainingSession(date: "2026-11-01",
                            lifts: [LoggedLift(exerciseId: "back-squat",
                                               sets: [HabitaBullKit.LoggedSet(weight: 150, reps: 5, done: true)])]),
        ]
        let old = Goal(exerciseId: "back-squat", targetWeight: 200, targetDate: "2027-01-01")
        XCTAssertEqual(Goals.progress(history, old), 50, "the fixture is not the case being tested")

        let kept = GoalScreen.startWeight(for: "back-squat", existing: old,
                                          history: history, best: 150)
        XCTAssertEqual(kept, 100,
                       "saving the goal she is looking at reset it to today's best, which "
                       + "reads as no progress at all")
        XCTAssertEqual(Goals.progress(history, Goal(exerciseId: "back-squat", targetWeight: 200,
                                                    targetDate: "2027-02-01", startWeight: kept)),
                       50, "changing only the date moved the bar")

        // a goal on a different lift is a new goal, and starts from now
        XCTAssertEqual(GoalScreen.startWeight(for: "deadlift", existing: old,
                                              history: history, best: 150), 150)
    }

    func testRemovingTheGoalLeavesTheRestOfHerAlone() {
        let store = ProfileStore(defaults: defaults)
        store.save(Profile(name: "Lucy", motivation: "It clears my head.", trainingDays: [1],
                           weekChosen: true,
                           goal: Goal(exerciseId: "deadlift", targetWeight: 225,
                                      targetDate: "2027-01-01")))
        store.update { $0.goal = nil }

        let later = ProfileStore(defaults: defaults)
        XCTAssertNil(later.profile?.goal)
        XCTAssertEqual(later.profile?.why, "It clears my head.")
        XCTAssertEqual(later.profile?.trainingDays, [1])
    }

    func testAProfileSavedBeforeGoalsExistedStillOpens() {
        // the field did not exist when this was written to disk. a throw here
        // reads as "no profile", which would put onboarding in front of
        // somebody who finished it months ago and lose her reason with it.
        let old = """
        {"name":"Lucy","motivation":"It clears my head.","trainingDays":[1,3,5],
         "weekChosen":true,"createdAt":0}
        """
        defaults.set(Data(old.utf8), forKey: "profile")

        let store = ProfileStore(defaults: defaults)
        XCTAssertFalse(store.needsOnboarding)
        XCTAssertNil(store.profile?.goal)
        XCTAssertEqual(store.profile?.why, "It clears my head.")
    }

    // MARK: - what the plan says before she starts it

    func testThePlanSaysTheWeightAndNotJustTheShape() {
        let squat = LoggedExercise(exerciseId: "back-squat",
                                   sets: Array(repeating: LoggedSet(weight: 147.5, reps: 8), count: 3))
        XCTAssertEqual(squat.planLine, "3 × 8")
        XCTAssertEqual(squat.planDetail, "3 × 8 · 147.5 lb")
    }

    func testALiftWithNothingOnItJustSaysTheShape() {
        let pushUp = LoggedExercise(exerciseId: "push-up",
                                    sets: Array(repeating: LoggedSet(weight: 0, reps: 12), count: 3))
        XCTAssertEqual(pushUp.planDetail, pushUp.planLine,
                       "a bodyweight lift has no weight to report")

        let plank = LoggedExercise(exerciseId: "plank", sets: [LoggedSet(weight: 0, reps: 30)])
        XCTAssertEqual(plank.planDetail, "1 × 30 sec")
    }
}

// MARK: - the routine, on disk

extension GoalTests {
    func testARoutineSurvivesTheAppClosing() {
        var week = Planner.plan(for: [1, 3, 5])
        week.rename("Leg day", to: "Legs and core")
        week.setLifts(["back-squat", "plank"], of: "Legs and core")

        let store = ProfileStore(defaults: defaults)
        store.save(Profile(name: "Lucy", trainingDays: [1, 3, 5], weekChosen: true, routine: week))

        let later = ProfileStore(defaults: defaults)
        XCTAssertEqual(later.profile?.routine?.label(on: 5), "Legs and core")
        XCTAssertEqual(later.profile?.routine?.lifts(on: 5), ["back-squat", "plank"])
    }
}
