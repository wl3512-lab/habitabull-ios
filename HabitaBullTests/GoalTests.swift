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
            $0.goal = Goal(exerciseId: "back-squat", targetWeight: 185, targetDate: "2026-12-30")
        }

        let later = ProfileStore(defaults: defaults)
        XCTAssertEqual(later.profile?.goal?.exerciseId, "back-squat")
        XCTAssertEqual(later.profile?.goal?.targetWeight, 185)
        XCTAssertEqual(later.profile?.goal?.targetDate, "2026-12-30")
        XCTAssertEqual(later.profile?.name, "Lucy", "setting a goal rewrote the rest of her")
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
