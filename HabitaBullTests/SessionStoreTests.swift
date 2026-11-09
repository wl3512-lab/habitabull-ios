//
// the rules, without a screen in front of them. these run in under a second,
// which is the point: the web version's bugs were all in rules like these and
// the only way to see one was to stand in a gym and hit it.
//
// every test writes to its own temporary file, so nothing here can touch a
// workout on a real phone or leave anything behind.

import XCTest
import HabitaBullKit
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

    // MARK: - what the screen between lifts offers

    func testTheLiftsLeftAreTheOnesWithSetsLeftInTheOrderTheySit() {
        store.startWorkout()
        store.addLift("hammer-curl", sets: 2)
        guard let session = store.today else { return XCTFail("no workout") }
        XCTAssertEqual(session.liftsLeft, Array(session.exercises.indices))

        // finish the first one and it drops out, the rest keep their places
        for _ in session.exercises[0].sets { store.logSet(onExercise: 0, weight: 95, reps: 8) }
        XCTAssertEqual(store.today?.liftsLeft, [1, 2])
    }

    func testTheFirstLiftLeftIsAlwaysTheOneTheAppWouldHaveOpened() {
        // the screen offers the first of liftsLeft as the plan's next lift,
        // and the log screen falls back to nextSet. they have to be the same
        // lift or the screen names one and the app opens another
        store.startWorkout()
        store.addLift("hammer-curl", sets: 2)
        guard var session = store.today else { return XCTFail("no workout") }
        XCTAssertEqual(session.liftsLeft.first, session.nextSet?.exercise)

        store.logSet(onExercise: 1, weight: 180, reps: 10)   // out of order, on purpose
        session = store.today!
        XCTAssertEqual(session.liftsLeft.first, session.nextSet?.exercise)

        for e in session.exercises.indices {
            for _ in session.exercises[e].sets { store.logSet(onExercise: e, weight: 50, reps: 5) }
        }
        XCTAssertEqual(store.today?.liftsLeft, [])
        XCTAssertNil(store.today?.nextSet)
    }

    // MARK: - where a lift opens, and why

    func testClearingEverySetMakesTheWeightGoUpOnItsOwn() {
        // three sets of eight at 95, which is what the plan asked for
        givenPastWorkouts([day("2026-11-01", "back-squat", weight: 95, reps: 8)])
        store.startWorkout()

        let squat = store.today!.exercises[indexOf("back-squat")]
        XCTAssertEqual(squat.sets.first?.weight, 97.5, "she cleared it and the bar did not move")
        XCTAssertEqual(squat.sets.first?.reps, 8)
        XCTAssertEqual(store.reasonForNext(of: "back-squat"), "Up 2.5 lb. You earned it.")
    }

    func testMissingRepsHoldsYouAtTheSameWeight() {
        // the plan asked for eight and she got six on every set
        givenPastWorkouts([day("2026-11-01", "back-squat", weight: 95, reps: 6)])
        store.startWorkout()

        XCTAssertEqual(store.today!.exercises[indexOf("back-squat")].sets.first?.weight, 95)
        XCTAssertEqual(store.reasonForNext(of: "back-squat"), "Same weight. Own it this time.")
    }

    func testThreeHardSessionsInARowBackYouOff() {
        givenPastWorkouts([
            day("2026-10-26", "back-squat", weight: 200, reps: 5),
            day("2026-10-29", "back-squat", weight: 200, reps: 5),
            day("2026-11-01", "back-squat", weight: 200, reps: 5),
        ])
        store.startWorkout()

        // ten percent off 200, snapped to something you can load
        XCTAssertEqual(store.today!.exercises[indexOf("back-squat")].sets.first?.weight, 180)
        XCTAssertEqual(store.reasonForNext(of: "back-squat"),
                       "Backing off 10%. Three tough sessions is a signal, not a failure.")
    }

    func testALiftYouHaveNeverDoneStartsWhereTheLibrarySaysNotAtZero() {
        store.startWorkout()
        store.addLift("dumbbell-hammer-curl", sets: 3)
        let curl = store.today!.exercises[indexOf("dumbbell-hammer-curl")]

        // light, loadable and not nothing. the exact number is the rules'
        // business and is pinned by the package's own tests
        let step = ExerciseLibrary.find("dumbbell-hammer-curl")!.increment
        let weight = curl.sets.first!.weight
        XCTAssertGreaterThan(weight, 0)
        XCTAssertLessThan(weight, 45, "a first dumbbell curl should not open near a barbell")
        XCTAssertEqual(weight.truncatingRemainder(dividingBy: step), 0, "not a weight you can pick up")
        XCTAssertEqual(store.reasonForNext(of: "dumbbell-hammer-curl"),
                       "First time. Start light and learn the movement.")
    }

    func testALiftYouAddAgainComesBackWhereYouLeftItAndWithTheSetsYouDid() {
        givenPastWorkouts([day("2026-11-01", "dumbbell-hammer-curl", weight: 25, reps: 12, sets: 4)])
        store.startWorkout()
        store.addLift("dumbbell-hammer-curl", sets: store.setsLastTime(of: "dumbbell-hammer-curl") ?? 3)
        let curl = store.today!.exercises[indexOf("dumbbell-hammer-curl")]

        // she cleared twelve, so it goes up by the curl's own step, and the
        // four sets she actually did come back with it
        XCTAssertEqual(curl.sets.count, 4)
        XCTAssertEqual(curl.sets.first?.weight, 25 + ExerciseLibrary.find("dumbbell-hammer-curl")!.increment)
    }

    func testTodaysOwnSetsDoNotDecideTodaysOwnWeight() {
        givenPastWorkouts([day("2026-11-01", "back-squat", weight: 95, reps: 8)])
        store.startWorkout()
        let squat = indexOf("back-squat")
        store.logSet(onExercise: squat, weight: 100, reps: 8)

        // the open workout is not its own history: clearing the first set must
        // not push the sets left in the same lift up to 105
        XCTAssertEqual(store.reasonForNext(of: "back-squat"), "Up 2.5 lb. You earned it.")
        XCTAssertEqual(store.today!.exercises[squat].sets.last?.weight, 100)
    }

    func testALiftYouSettledAtTwoSetsStillGetsHeavier() {
        // four sets was the plan once, then she settled at two and clears both
        givenPastWorkouts([day("2026-11-01", "dumbbell-hammer-curl", weight: 25, reps: 12, sets: 2)])
        store.startWorkout()
        store.addLift("dumbbell-hammer-curl", sets: store.setsLastTime(of: "dumbbell-hammer-curl") ?? 3)
        let curl = store.today!.exercises[indexOf("dumbbell-hammer-curl")]

        // judged against the three sets a new lifter is given, two cleared
        // sets would read as a miss and the weight would never move again
        XCTAssertEqual(curl.sets.count, 2)
        XCTAssertEqual(curl.sets.first?.weight, 27.5)
        XCTAssertEqual(store.reasonForNext(of: "dumbbell-hammer-curl"), "Up 2.5 lb. You earned it.")
    }

    func testTodayShowsTheWorkoutYouActuallyGet() {
        givenPastWorkouts([day("2026-11-01", "back-squat", weight: 95, reps: 8)])
        // what the card previews before you tap Start
        let preview = store.plannedToday
        store.startWorkout()
        let started = store.today!.exercises

        XCTAssertEqual(preview.map(\.exerciseId), started.map(\.exerciseId))
        XCTAssertEqual(preview.map { $0.sets.count }, started.map { $0.sets.count })
        XCTAssertEqual(preview.map { $0.sets.first?.weight }, started.map { $0.sets.first?.weight })
        XCTAssertEqual(preview.map { $0.sets.first?.reps }, started.map { $0.sets.first?.reps })
    }

    func testTheAppAndTheRulesAgreeOnTheSameLift() {
        // the seam itself: the app's own translation, read back in the rules'
        // terms, so a future change to either side has to keep them matching
        givenPastWorkouts([day("2026-11-01", "back-squat", weight: 95, reps: 8)])
        let target: Target = store.nextTarget(of: "back-squat")
        XCTAssertEqual(target.weight, 97.5)
        XCTAssertEqual(target.sets, 3)

        let squat = ExerciseLibrary.find("back-squat")!
        XCTAssertEqual(squat.shape, LiftShape(increment: 2.5, compound: true, heavy: false,
                                              hold: false, cardio: false))
    }

    // MARK: - what the second number counts

    func testALiftSaysWhatItsSecondNumberCounts() {
        func lift(_ id: String) -> LoggedExercise {
            LoggedExercise(exerciseId: id, sets: [LoggedSet(weight: 0, reps: 30)])
        }
        // a squat is repetitions, a plank is seconds, a treadmill is minutes,
        // and a machine crunch is reps even though it trains the same muscle
        XCTAssertEqual(lift("back-squat").counted, .reps)
        XCTAssertEqual(lift("plank").counted, .seconds)
        XCTAssertEqual(lift("treadmill").counted, .minutes)
        XCTAssertEqual(lift("ab-crunch-machine").counted, .reps)
        // a lift the library has never heard of counts reps rather than guessing
        XCTAssertEqual(lift("custom-something").counted, .reps)
    }

    func testEachOneReadsAndStepsInItsOwnUnits() {
        let plank = LoggedExercise(exerciseId: "plank", sets: [LoggedSet(weight: 0, reps: 30)])
        XCTAssertEqual(plank.describe(plank.sets[0]), "30 sec")
        XCTAssertEqual(plank.countLabel, "Seconds")
        XCTAssertEqual(plank.countStep, 5)   // nobody holds a plank for 31

        let run = LoggedExercise(exerciseId: "treadmill", sets: [LoggedSet(weight: 0, reps: 20)])
        XCTAssertEqual(run.describe(run.sets[0]), "20 min")
        XCTAssertEqual(run.countLabel, "Minutes")

        let pushUp = LoggedExercise(exerciseId: "push-up", sets: [LoggedSet(weight: 0, reps: 12)])
        XCTAssertEqual(pushUp.describe(pushUp.sets[0]), "12 reps")
        XCTAssertEqual(pushUp.countStep, 1)  // six pull-ups is a number people have

        let squat = LoggedExercise(exerciseId: "back-squat", sets: [LoggedSet(weight: 135, reps: 5)])
        XCTAssertEqual(squat.describe(squat.sets[0]), "135 lb × 5")
    }

    func testTheLimitsBelongToTheUnitToo() {
        let plank = LoggedExercise(exerciseId: "plank", sets: [LoggedSet(weight: 0, reps: 30)])
        // stepping down from 30 by fives has to land on a number the plus can
        // reach again, so the floor is a multiple of the step, not 1
        XCTAssertEqual(plank.countRange.lowerBound, 5)
        XCTAssertEqual(plank.countRange.lowerBound.truncatingRemainder(dividingBy: plank.countStep), 0)
        var value = 30.0
        for _ in 0..<10 { value = max(plank.countRange.lowerBound, value - plank.countStep) }
        XCTAssertEqual(value, 5, "the minus walked off the fives")
        value = min(plank.countRange.upperBound, value + plank.countStep)
        XCTAssertEqual(value, 10)

        // a five minute wall sit has to be enterable
        XCTAssertGreaterThanOrEqual(plank.countRange.upperBound, 300)

        let run = LoggedExercise(exerciseId: "treadmill", sets: [LoggedSet(weight: 0, reps: 20)])
        XCTAssertEqual(run.countStep, 5)
        XCTAssertEqual(run.countRange.lowerBound, 5)

        // reps still move one at a time and still start at one
        let squat = LoggedExercise(exerciseId: "back-squat", sets: [LoggedSet(weight: 135, reps: 5)])
        XCTAssertEqual(squat.countRange, 1...200)
    }

    func testEachLiftSaysItsSetsOutLoudInItsOwnUnits() {
        let plank = LoggedExercise(exerciseId: "plank", sets: [LoggedSet(weight: 0, reps: 30)])
        // no pounds on a lift with no weight, and "seconds" rather than "sec"
        XCTAssertEqual(plank.spoken(plank.sets[0]), "30 seconds")
        XCTAssertEqual(plank.planLine, "1 × 30 sec")

        let run = LoggedExercise(exerciseId: "treadmill", sets: [LoggedSet(weight: 0, reps: 20)])
        XCTAssertEqual(run.spoken(run.sets[0]), "20 minutes")

        let squat = LoggedExercise(exerciseId: "back-squat",
                                   sets: [LoggedSet(weight: 135, reps: 5), LoggedSet(weight: 135, reps: 5),
                                          LoggedSet(weight: 135, reps: 5)])
        XCTAssertEqual(squat.spoken(squat.sets[0]), "135 pounds for 5 reps")
        XCTAssertEqual(squat.planLine, "3 × 5", "reps need no unit, and never did")
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

    /// History from before today, written the way the app writes it and read
    /// back through the store's own loader. No clock is moved: a workout on an
    /// earlier date is just a different string, which is how the app stores it
    /// anyway.
    private func givenPastWorkouts(_ past: [Session]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try! encoder.encode(past).write(to: file)
        store = SessionStore(fileURL: file)
    }

    /// One finished day: every set logged, at the weight and count given.
    private func day(_ date: String, _ id: String, weight: Double, reps: Int, sets: Int = 3) -> Session {
        Session(id: UUID().uuidString, date: date, label: "Leg day",
                exercises: [LoggedExercise(exerciseId: id,
                                           sets: Array(repeating: LoggedSet(weight: weight, reps: reps, done: true),
                                                       count: sets))],
                startedAt: .now, completedAt: .now)
    }

    private func indexOf(_ id: String) -> Int {
        store.today?.exercises.firstIndex { $0.exerciseId == id } ?? -1
    }
}
