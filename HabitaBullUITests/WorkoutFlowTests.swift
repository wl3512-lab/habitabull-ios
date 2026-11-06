//
// the three things Lucy reported on November 6, driven through the real app in
// the simulator. one workout, start to finish, asserting as it goes:
//
//   1. resting after the last set of a lift offers "One more set of X" and does
//      not also offer the +/- row, which was two controls for one decision
//   2. the first set of a lift she has never done says so
//   3. finishing a lift she added mid-workout goes back to the lift she has not
//      done, instead of ending the workout
//
// it drives the UI rather than the store on purpose: all three were reported as
// what the screen did, and the store was right in every one of them.

import XCTest

final class WorkoutFlowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // a clean slate every run: the starter workout, and no lift with any
        // history, which is what makes the first-time beat testable at all
        app.launchArguments = ["-uitest-reset"]
        app.launch()
    }

    func testAddingALiftDoesNotEndTheWorkout() {
        start()

        // Back Squat, three sets. The rest screen stands between them.
        logSet(expecting: "New lift")      // never done before on a clean slate
        leaveRest()
        logSet()
        leaveRest()
        logSet()

        // (1) resting after the last set of a lift: one control, not two
        let rest = app.buttons["Done resting"]
        XCTAssertTrue(rest.waitForExistence(timeout: 10), "the rest screen never opened")
        XCTAssertTrue(app.buttons["One more set of Back Squat"].exists,
                      "no way to add one more set of the lift just finished")
        XCTAssertFalse(app.buttons["Add a set to this lift"].exists,
                       "the set-count row is still here beside One more set")
        rest.tap()

        // Leg Press is next and untouched. Add a lift in the middle of it.
        XCTAssertTrue(app.staticTexts["Leg Press"].waitForExistence(timeout: 5))
        addLift(named: "Hammer Curl")

        // (2) a lift she has never done says so on its first set
        logSet(expecting: "New lift")
        leaveRest()
        logSet()
        leaveRest()
        logSet()

        // (3) the workout is not over: Leg Press has had nothing logged on it
        leaveRest()
        XCTAssertTrue(app.staticTexts["Leg Press"].waitForExistence(timeout: 5),
                      "finishing the added lift did not go back to the lift still to do")
        XCTAssertFalse(app.staticTexts["That's every set."].exists,
                       "the workout ended with Leg Press untouched")
    }

    // the other half of the same report: a workout should not end while there
    // are sets left in it without saying so first. End asks, and Keep going
    // puts her back on the set she was on with nothing lost
    func testEndingEarlyAsksAndCanBeTakenBack() {
        start()
        logSet()
        leaveRest()

        app.buttons["End"].tap()
        XCTAssertTrue(app.staticTexts["FINISH HERE?"].waitForExistence(timeout: 5),
                      "End finished the workout without asking")
        // it says what is being left behind, rather than only how much is done
        XCTAssertTrue(app.staticTexts["1 set logged, 5 sets not done."].exists,
                      "the question does not say what is not done")

        app.buttons["Keep going"].tap()
        XCTAssertTrue(app.buttons["Log set"].waitForExistence(timeout: 5),
                      "Keep going did not go back to the workout")
        XCTAssertTrue(app.staticTexts["Back Squat"].exists, "it came back on a different lift")
    }

    // MARK: - the flow, in the app's own words

    private func start() {
        let begin = app.buttons["Start workout"]
        XCTAssertTrue(begin.waitForExistence(timeout: 10), "Today never appeared")
        begin.tap()
        XCTAssertTrue(app.buttons["Log set"].waitForExistence(timeout: 5), "the log screen never opened")
    }

    /// Taps Log set and waits out the beat, checking what it said when asked.
    private func logSet(expecting beat: String? = nil, line: UInt = #line) {
        let log = app.buttons["Log set"]
        XCTAssertTrue(log.waitForExistence(timeout: 10), "no Log set button", line: line)
        log.tap()
        if let beat {
            XCTAssertTrue(app.staticTexts[beat].waitForExistence(timeout: 3),
                          "the beat did not say \(beat)", line: line)
        }
        // the beat clears itself; tapping it only gets there sooner
        app.tap()
    }

    /// The rest screen, when there is one. Returns to the working screen.
    private func leaveRest() {
        let done = app.buttons["Done resting"]
        if done.waitForExistence(timeout: 6) { done.tap() }
    }

    private func addLift(named name: String) {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Exercise '")).firstMatch.tap()
        app.buttons["Add a lift"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5), "the lift picker never opened")
        search.tap()
        search.typeText(name)
        app.buttons[name].firstMatch.tap()
        // step two is the set count, which opens on what she did last time
        let add = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Add ' AND label CONTAINS 'set'")).firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5), "the sets step never opened")
        add.tap()
    }
}
