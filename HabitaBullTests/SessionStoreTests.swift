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

    // MARK: - saving after a save has failed

    /// A write can fail for a moment: storage full, the file busy, the phone
    /// mid backup. The store used to latch on the first failure and refuse
    /// every write after it, so logging carried on updating memory, the
    /// screen looked right, and the rest of the workout was gone on relaunch.
    /// Losing the sets after a hiccup is far worse than the hiccup.
    /// Found by a codex review 2026-11-15.
    func testSavingComesBackAfterAWriteFails() {
        // a file inside a directory that is not there yet: every write fails
        let missing = URL.temporaryDirectory.appending(path: "gone-\(UUID().uuidString)")
        let path = missing.appending(path: "sessions.json")
        let store = SessionStore(fileURL: path)

        store.startWorkout()
        store.addLift("hammer-curl", sets: 3)
        store.logSet(onExercise: indexOf("hammer-curl", in: store), weight: 25, reps: 12)
        XCTAssertTrue(store.saveFailed, "a failed write should say so")

        // the phone starts saving again
        try! FileManager.default.createDirectory(at: missing, withIntermediateDirectories: true)
        store.logSet(onExercise: indexOf("hammer-curl", in: store), weight: 25, reps: 12)

        XCTAssertFalse(store.saveFailed, "it is saving again and still says it is not")
        let reopened = SessionStore(fileURL: path)
        XCTAssertEqual(reopened.sessions.flatMap(\.exercises).flatMap(\.sets).filter(\.done).count, 2,
                       "the sets she did after the hiccup did not survive a relaunch")
        try? FileManager.default.removeItem(at: missing)
    }

    /// On a machine that counts help, a record is needing less of it.
    ///
    /// Reading those lifts the ordinary way congratulated her for taking more
    /// help than last time, and never noticed when she took less.
    /// Found by a codex review 2026-11-16.
    func testARecordOnAnAssistedLiftIsLessHelpNotMore() {
        store.startWorkout()
        store.addLift("assisted-pull-up", sets: 3)
        let pullUp = indexOf("assisted-pull-up")

        let first = store.logSet(onExercise: pullUp, weight: 45, reps: 8)
        XCTAssertEqual(first?.kind, .first, "the first time on a lift is never a record")

        let moreHelp = store.logSet(onExercise: pullUp, weight: 50, reps: 8)
        XCTAssertEqual(moreHelp?.kind, .routine, "it called taking more help a record")

        let lessHelp = store.logSet(onExercise: pullUp, weight: 40, reps: 8)
        XCTAssertEqual(lessHelp?.kind, .best, "needing less help than ever did not count")
        XCTAssertEqual(lessHelp?.gain, 5, "the gain is the help she stopped needing")
    }

    /// A goal is a number of pounds to reach, which an assisted lift cannot be.
    func testAnAssistedLiftIsNotSomethingToSetAGoalOn() {
        let allowed = ExerciseLibrary.forGoals.map(\.id)
        XCTAssertFalse(allowed.contains("assisted-pull-up"))
        XCTAssertFalse(allowed.contains("assisted-dip"))
        XCTAssertTrue(allowed.contains("back-squat"), "it kept out a lift a goal belongs on")
    }

    /// Redoing a set she has already logged corrects that set and leaves the
    /// rest of them alone.
    ///
    /// Tapping a logged set used to mark it not-done in the store and save
    /// that straight away, so a correction she had not finished was already a
    /// fact about the workout: put the phone down in the middle of one and the
    /// set she had done came back as one she had not. The correction lives on
    /// the screen now, and the store is told which set to write.
    /// Found by a codex audit 2026-11-15.
    func testRedoingASetCorrectsThatOneAndCountsTheRest() {
        store.startWorkout()
        let squat = indexOf("back-squat")
        store.logSet(onExercise: squat, weight: 95, reps: 8)
        store.logSet(onExercise: squat, weight: 95, reps: 5)

        store.logSet(onExercise: squat, weight: 100, reps: 8, replacing: 0)

        let sets = store.today!.exercises[squat].sets
        XCTAssertEqual(sets[0].weight, 100, "the correction went to the wrong set")
        XCTAssertEqual(sets[0].reps, 8)
        XCTAssertTrue(sets[0].done)
        XCTAssertTrue(sets[1].done, "the set she was not correcting stopped counting")
        XCTAssertEqual(sets.filter(\.done).count, 2)
    }

    /// A set index that is not there falls back to the next one she has not
    /// done, rather than losing the set.
    func testRedoingASetThatIsNotThereLogsTheNextOne() {
        store.startWorkout()
        let squat = indexOf("back-squat")

        store.logSet(onExercise: squat, weight: 95, reps: 8, replacing: 99)

        XCTAssertEqual(store.today!.exercises[squat].sets.filter(\.done).count, 1)
    }

    /// And a file that will not open is not a file that is not there.
    ///
    /// Every read failure went down the same path as an ordinary first run:
    /// the store came up empty, said nothing about it, and the first set she
    /// logged wrote over every workout she had ever done. A file she has no
    /// permission to read is the cheapest way to stand in for a disk going
    /// wrong. Found by a codex review 2026-11-15.
    func testHistoryIsNotWrittenOverWhenTheFileWillNotOpen() throws {
        let path = URL.temporaryDirectory.appending(path: "locked-\(UUID().uuidString).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode([day("2026-11-01", "back-squat", weight: 95, reps: 8)]).write(to: path)
        let fm = FileManager.default
        try fm.setAttributes([.posixPermissions: 0], ofItemAtPath: path.path)
        defer {
            try? fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: path.path)
            try? fm.removeItem(at: path)
        }

        let store = SessionStore(fileURL: path)
        XCTAssertTrue(store.sessions.isEmpty, "it read a file it cannot read")
        XCTAssertTrue(store.saveFailed, "it could not open her history and said nothing")

        store.startQuickWorkout()
        store.addLift("hammer-curl", sets: 3)

        try fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: path.path)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let back = try decoder.decode([Session].self, from: Data(contentsOf: path))
        XCTAssertEqual(back.count, 1, "her history was written over by a workout started on top of it")
        XCTAssertEqual(back.first?.exercises.first?.exerciseId, "back-squat")
    }

    /// The other half of the same decision: a file that could not be read is
    /// never written over, so a history worth recovering by hand stays put.
    func testAnUnreadableFileIsNeverSavedOver() {
        let path = URL.temporaryDirectory.appending(path: "junk-\(UUID().uuidString).json")
        let junk = Data("this is not a workout".utf8)
        try! junk.write(to: path)

        let store = SessionStore(fileURL: path)
        XCTAssertTrue(store.saveFailed, "it could not read the file and did not say so")
        store.startWorkout()

        XCTAssertEqual(try! Data(contentsOf: path), junk, "it wrote over a file it could not read")
        try? FileManager.default.removeItem(at: path)
    }

    // MARK: - a workout that runs past midnight

    /// Seeds one open workout that began at 23:50 and is still open now, which
    /// is exactly what the store sees the moment the date rolls over. No clock
    /// is faked: the session is written to disk the way it would already be.
    /// Two years of lifting: 300 workouts, five lifts each, four sets each.
    /// Roughly what she will have if the app is any good.
    private func seedTwoYears() {
        let lifts = ["back-squat", "bench-press", "deadlift", "barbell-row", "overhead-press"]
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let sessions: [Session] = (1...300).map { back in
            let day = cal.date(byAdding: .day, value: -back, to: .now)!
            return Session(
                id: UUID().uuidString,
                date: dayString(day),
                label: "Full body",
                exercises: lifts.map { id in
                    LoggedExercise(exerciseId: id,
                                   sets: Array(repeating: LoggedSet(weight: 135, reps: 5, done: true),
                                               count: 4))
                },
                startedAt: day,
                completedAt: day.addingTimeInterval(3600)
            )
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try! encoder.encode(sessions).write(to: file)
        store = SessionStore(fileURL: file)
    }

    /// Planning today's lifts against two years of history must not take
    /// longer than a blink, because Today works it out again on every redraw
    /// and the logging screen asks for it while she is typing a weight.
    ///
    /// `nextTarget` filtered the sessions with `sessionInHandId` written
    /// inside the closure, so it was re-derived once per session, and
    /// deriving it scans the sessions and builds a `Calendar` for each one.
    /// At 300 sessions that is about ninety thousand calendar builds for one
    /// lift, and Today asks for every lift on the card.
    /// Found by a codex audit 2026-11-16.
    func testPlanningAgainstTwoYearsOfHistoryIsQuick() {
        seedTwoYears()
        let lifts = ["back-squat", "bench-press", "deadlift", "barbell-row", "overhead-press"]

        let began = Date.now
        for _ in 0..<3 {            // Today reads the plan more than once per redraw
            for id in lifts { _ = store.planned(id) }
        }
        let took = Date.now.timeIntervalSince(began)

        XCTAssertLessThan(took, 0.5,
                          "planning five lifts three times took \(took)s against 300 sessions")
    }

    private func seedWorkoutStartedLastNight(lift: String = "back-squat", done: Bool = false) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let tenToMidnight = cal.startOfDay(for: .now).addingTimeInterval(-10 * 60)
        let session = Session(
            id: UUID().uuidString,
            date: dayString(tenToMidnight),
            label: "Leg day",
            exercises: [LoggedExercise(exerciseId: lift,
                                       sets: Array(repeating: LoggedSet(weight: 95, reps: 8, done: done),
                                                   count: 3))],
            startedAt: tenToMidnight
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try! encoder.encode([session]).write(to: file)
        store = SessionStore(fileURL: file)
    }

    /// The morning after a workout she walked away from.
    ///
    /// The fix above left every unfinished workout from the last 24 hours
    /// looking open, and the rules leave the open workout out of its own
    /// history. So the planner left last night's three sets of 95 out of the
    /// history it was planning from: today's squat opened at the empty bar
    /// while the line underneath recommended 100. A workout she is not in is
    /// history like any other. Found by a codex review 2026-11-15.
    func testPlanningAfterAWorkoutSheWalkedAwayFromStillCountsIt() {
        seedWorkoutStartedLastNight(done: true)
        XCTAssertNil(store.sessionInHandId, "she is not standing in last night's workout")

        store.startWorkout()

        let squat = store.today!.exercises[indexOf("back-squat")]
        XCTAssertEqual(squat.sets.first?.weight, 97.5,
                       "last night's 95 was left out of its own history and the bar fell to the floor")
        XCTAssertEqual(store.reasonForNext(of: "back-squat"), "Up 2.5 lb. You earned it.")
    }

    /// Sets she logs now still go to last night's workout, because the app can
    /// be killed mid workout and reopened and the sets have to land somewhere
    /// she can see them.
    func testASetStillLandsOnLastNightsWorkoutAfterTheAppWasKilled() {
        seedWorkoutStartedLastNight()
        store.logSet(onExercise: 0, weight: 100, reps: 5)
        XCTAssertEqual(store.sessions.flatMap(\.exercises).flatMap(\.sets).filter(\.done).count, 1,
                       "the set went nowhere")
    }

    /// The receipt is for the workout she just finished, not whichever one the
    /// store can still write to.
    ///
    /// With last night's workout still open, finishing today's clears the
    /// open id and the store falls back to last night's, which is right for
    /// writes and wrong for a receipt: the screen said "that's the workout"
    /// over yesterday's lifts. This is why the log screen holds the id of the
    /// one it finished rather than asking again. Found by a codex review
    /// 2026-11-15.
    func testTheReceiptIsForTheWorkoutSheJustFinished() {
        seedWorkoutStartedLastNight(done: true)   // last night's, walked away from
        store.startWorkout()
        let todays = store.openSessionId
        store.logSet(onExercise: indexOf("back-squat"), weight: 100, reps: 5)

        store.finishWorkout()

        let receipt = store.session(id: todays)
        XCTAssertNotNil(receipt?.completedAt, "today's workout is not the one that got finished")
        XCTAssertEqual(receipt?.date, dayString(), "the receipt is for another day")
        XCTAssertNotEqual(store.openSession?.id, todays,
                          "asking the store again lands on last night's, which is the trap")
    }

    /// The receipt after a workout that ran past midnight.
    ///
    /// Finishing closes the open session, and `today` is already a different
    /// day, so the screen that says "that's the workout" had nothing left to
    /// name: no receipt, and the toolbar hidden behind the same flag, which
    /// left her on a blank screen with no way back. The id is hers to hold.
    /// Found by a codex review 2026-11-15.
    func testTheWorkoutIsStillThereToShowHerAfterSheFinishesItPastMidnight() {
        seedWorkoutStartedLastNight()
        store.logSet(onExercise: 0, weight: 100, reps: 5)
        let id = store.openSessionId
        XCTAssertNotNil(id)

        store.finishWorkout()

        XCTAssertNil(store.today, "it is a different day: today has nothing to show")
        XCTAssertNil(store.openSessionId, "it is finished and should not read as open")
        let receipt = store.session(id: id)
        XCTAssertNotNil(receipt, "the workout she just finished could not be shown back to her")
        XCTAssertNotNil(receipt?.completedAt)
        XCTAssertEqual(receipt?.exercises.first?.sets.filter(\.done).count, 1)
    }

    /// Midnight is not the end of a workout. The store used to find the open
    /// session by today's date, so at 00:00 it stopped finding the one she was
    /// standing in the middle of: logSet and finishWorkout quietly did nothing
    /// while the screen still looked fine. Found by a codex review 2026-11-15.
    func testASetLoggedAfterMidnightLandsOnTheWorkoutSheIsStillDoing() {
        seedWorkoutStartedLastNight()
        XCTAssertNotNil(store.openSessionId, "the workout she is in the middle of went missing at midnight")

        store.logSet(onExercise: 0, weight: 100, reps: 5)

        let done = store.sessions.flatMap(\.exercises).flatMap(\.sets).filter(\.done)
        XCTAssertEqual(done.count, 1, "the set went nowhere")
        XCTAssertEqual(done.first?.weight, 100)
    }

    /// The write path was fixed first and the read path was not, which a
    /// second codex pass caught: the logging screen reads the session back and
    /// was still asking for today's, so it emptied out and said "That's every
    /// set" on a workout with sets left in it.
    func testTheWorkoutSheIsStillDoingCanBeReadBackAfterMidnight() {
        seedWorkoutStartedLastNight()
        XCTAssertNil(store.today, "this test is pointless if today still finds it")
        let open = store.openSession
        XCTAssertNotNil(open, "the screen asking for the open workout got nothing")
        XCTAssertEqual(open?.exercises.first?.exerciseId, "back-squat")
        XCTAssertEqual(open?.exercises.first?.setsLeft, 3, "it lost the sets she has left")
    }

    func testAWorkoutThatRanPastMidnightCanStillBeFinished() {
        seedWorkoutStartedLastNight()
        store.logSet(onExercise: 0, weight: 100, reps: 5)
        store.finishWorkout()

        XCTAssertNotNil(store.sessions.first?.completedAt,
                        "she finished it and it stayed open for ever")
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

    func testTheBackOffStopsAtTheEmptyBar() {
        // the phone's end of the floor: three hard sessions at the bar used to
        // open the next one at 40, then 36, then 32.5, which is a squat nobody
        // can set up
        givenPastWorkouts([
            day("2026-10-26", "back-squat", weight: 45, reps: 5),
            day("2026-10-29", "back-squat", weight: 45, reps: 5),
            day("2026-11-01", "back-squat", weight: 45, reps: 5),
        ])
        store.startWorkout()

        XCTAssertEqual(store.today!.exercises[indexOf("back-squat")].sets.first?.weight, 45)
        XCTAssertEqual(store.reasonForNext(of: "back-squat"),
                       "This is as light as it loads. Stay here until it moves.")
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
                                              hold: false, cardio: false, floor: 45))
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
    ///
    /// It started on the day it says it did. The app only ever writes a date
    /// that agrees with `startedAt`, and a load now repairs one that is years
    /// out of place, so a fixture that disagrees is a fixture about nothing.
    private func day(_ date: String, _ id: String, weight: Double, reps: Int, sets: Int = 3) -> Session {
        let when = Attendance.date(date, Attendance.calendar()) ?? .now
        return Session(id: UUID().uuidString, date: date, label: "Leg day",
                       exercises: [LoggedExercise(exerciseId: id,
                                                  sets: Array(repeating: LoggedSet(weight: weight, reps: reps, done: true),
                                                              count: sets))],
                       startedAt: when, completedAt: when)
    }

    private func indexOf(_ id: String) -> Int {
        indexOf(id, in: store)
    }

    // the same, for a test that builds its own store on a different file
    private func indexOf(_ id: String, in store: SessionStore) -> Int {
        store.today?.exercises.firstIndex { $0.exerciseId == id } ?? -1
    }
}
