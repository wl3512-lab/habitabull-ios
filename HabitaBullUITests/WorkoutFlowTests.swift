//
// the workout loop, driven through the real app in the simulator rather than
// through the store. three of these started as things Lucy reported from a
// phone that turned out to be right in the code already, which is the
// expensive kind of uncertainty; the rest cover the screens since.
//
// one workout, start to finish, asserting as it goes:
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
        // an empty slate, and beats that wait to be read rather than expiring
        // while the query that reads them is still resolving. onboarded,
        // because these are about the workout loop and the three questions
        // have their own test
        app.launchArguments = ["-uitest-skip-opening", "-uitest-reset", "-uitest-onboarded", "-uitest-hold-beats"]
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
        onLift("Leg Press")
        addLift(named: "Hammer Curl")

        // (2) a lift she has never done says so on its first set
        logSet(expecting: "New lift")
        leaveRest()
        logSet()
        leaveRest()
        logSet()

        // (3) the workout is not over: Leg Press has had nothing logged on it
        leaveRest()
        onLift("Leg Press")
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

    // the screen between two lifts. it only appears when there is a real
    // choice, and the plan's order is the button at the bottom: keeping the
    // same order inside a block is what makes the numbers comparable
    func testTheScreenBetweenLiftsKeepsThePlansOrderAsTheDefault() {
        start()
        // two added lifts, so there is still a choice after the second one
        addLift(named: "Hammer Curl")
        addLift(named: "Lat Pulldown")
        // back onto the curl, which is where the first finish will come from
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Exercise '")).firstMatch.tap()
        app.buttons["Hammer Curl, 3 left"].tap()
        logSet(expecting: "New lift")
        leaveRest()
        logSet()
        leaveRest()
        logSet()
        leaveRest()

        XCTAssertTrue(app.staticTexts["HAMMER CURL DONE"].waitForExistence(timeout: 6),
                      "the between-lifts screen did not appear with two lifts left")
        // the plan's next lift is the one big button, one tap away
        XCTAssertTrue(app.buttons["Start Back Squat"].exists, "the planned lift is not the default")
        // and the other one is an alternative, not a peer
        let instead = app.buttons["Start Leg Press instead, 3 sets left"]
        XCTAssertTrue(instead.exists, "no way to take the other lift first")
        XCTAssertTrue(app.staticTexts["Your plan keeps its order. This is just today."].exists,
                      "nothing says the change is only for today")

        // it owns the screen: no End and no menu to tap behind it
        XCTAssertFalse(app.buttons["End"].exists, "the toolbar is still live over the chooser")
        // and it never offers the lift that was just finished
        XCTAssertFalse(app.buttons["Start Hammer Curl instead, 3 sets left"].exists)

        instead.tap()
        onLift("Leg Press")
        XCTAssertTrue(app.buttons["Log set"].exists)

        // finish this one too: the chooser comes back, and the plan's next
        // lift is now the squat she has not touched
        logSet(); leaveRest(); logSet(); leaveRest(); logSet(); leaveRest()
        XCTAssertTrue(app.staticTexts["LEG PRESS DONE"].waitForExistence(timeout: 6),
                      "the chooser did not come back for the second lift")
        let planned = app.buttons["Start Back Squat"]
        XCTAssertTrue(planned.exists)
        planned.tap()
        XCTAssertTrue(app.buttons["Log set"].waitForExistence(timeout: 5),
                      "the plan's own lift did not open")
        onLift("Back Squat")
    }

    // the way out for somebody who never found the menu in the corner: the
    // lift's own name is the control, because it is the thing they want to
    // change
    func testTappingTheLiftNameGetsYouOffTheWrongLift() {
        start()
        addLift(named: "Hammer Curl")   // three lifts, so there is a choice

        // she lands on the curl and actually wants the press first
        let title = app.buttons["Hammer Curl. Tap to do a different lift first"]
        XCTAssertTrue(title.waitForExistence(timeout: 6), "the lift name is not a way out")
        title.tap()

        XCTAssertTrue(app.staticTexts["SWITCH LIFT"].waitForExistence(timeout: 5))
        // the one she is on is in the list, so staying is a tap and not a hunt
        XCTAssertTrue(app.buttons["Stay on Hammer Curl"].exists)
        app.buttons["Switch to Leg Press, 3 sets left"].tap()

        onLift("Leg Press")
        XCTAssertTrue(app.buttons["Log set"].exists)
    }

    func testOneLiftLeftIsNotAChoiceWorthAScreen() {
        start()
        // the starter workout is two lifts: finishing the first leaves one,
        // and a screen offering a single option is a tap for nothing
        logSet()
        leaveRest()
        logSet()
        leaveRest()
        logSet()
        leaveRest()
        // wait for where it should land before asserting what is absent, or
        // the absence passes simply by being early
        XCTAssertTrue(app.buttons["Log set"].waitForExistence(timeout: 6))
        onLift("Leg Press")
        XCTAssertFalse(app.staticTexts["BACK SQUAT DONE"].exists, "it asked with nothing to ask about")
    }

    // MARK: - the flow, in the app's own words

    /// Type a weight, tap Log set, never tap Done. That is how it goes when
    /// you are holding a bar: the keyboard is still up and the next thing you
    /// want is the set logged. The typed number used to only be read when the
    /// field lost focus, so this logged whatever was there before and then
    /// showed that back on the rest screen as if she had asked for it. A
    /// wrong number she trusts is worse than no number. Found by a codex
    /// review on 2026-11-15.
    func testATypedWeightIsTheOneThatGetsLogged() {
        start()

        let tapToType = app.staticTexts["Type Weight instead"]
        XCTAssertTrue(tapToType.waitForExistence(timeout: 5), "no weight to tap")
        tapToType.tap()

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "the weight field never took focus")
        // clear the plan's suggestion, then ask for a weight nothing else on
        // this screen could have produced on its own
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8))
        field.typeText("100")

        app.buttons["Log set"].tap()
        // the beat clears itself; tapping only gets there sooner
        app.tap()

        let logged = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH '100 lb'")
        ).firstMatch
        if !logged.waitForExistence(timeout: 8) {
            let shown = app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " | ")
            XCTFail("logged a weight she did not type. on screen: \(shown)")
        }
    }

    /// The rest length has to be changeable after the first run. Every way
    /// into the rest screen in the real app arrives already resting, and the
    /// plus and minus row used to be hidden whenever it was, so whatever
    /// onboarding set was what she kept for good. Found by a codex review
    /// 2026-11-15.
    func testTheRestLengthCanStillBeChangedInTheMiddleOfAWorkout() {
        start()
        logSet()

        XCTAssertTrue(app.staticTexts["Resting"].waitForExistence(timeout: 8),
                      "the rest screen never arrived")
        let longer = app.buttons["+15s"]
        XCTAssertTrue(longer.waitForExistence(timeout: 5),
                      "no way to change the rest length while resting")

        let before = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES '[0-9]+:[0-9][0-9]'")
        ).firstMatch.label
        longer.tap()
        let after = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES '[0-9]+:[0-9][0-9]'")
        ).firstMatch.label
        XCTAssertNotEqual(before, after, "fifteen more seconds changed nothing on the clock")
    }

    /// The buttons and the keyboard set the same number and have to agree.
    /// Typing a weight and then tapping the plus moved the value behind a
    /// field still showing the old text, so the screen said one weight and
    /// the set saved another. Found by the second codex pass, 2026-11-15.
    func testSteppingAWeightSheHasTypedMovesWhatSheCanSee() {
        start()

        app.staticTexts["Type Weight instead"].tap()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "the weight field never took focus")
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8))
        field.typeText("100")

        app.buttons["Increase Weight"].tap()
        XCTAssertNotEqual(field.value as? String, "100",
                          "the plus moved the weight and left the screen saying 100")

        // and what it says is what gets logged, with Done never tapped
        let shown = (field.value as? String) ?? ""
        app.buttons["Log set"].tap()
        app.tap()
        let logged = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", shown + " lb")
        ).firstMatch
        if !logged.waitForExistence(timeout: 8) {
            let all = app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " | ")
            XCTFail("the screen said \(shown) and logged something else. on screen: \(all)")
        }
    }

    private func start() {
        let begin = app.buttons["Start workout"]
        // thirty, not ten. the first test in a suite runs right after a build
        // and install, and that launch has taken over forty seconds on this
        // machine. ten seconds made this suite fail at random on whichever
        // test happened to go first, which is worse than slow: a suite that
        // goes red for no reason stops being read
        XCTAssertTrue(begin.waitForExistence(timeout: 30), "Today never appeared")
        begin.tap()
        XCTAssertTrue(app.buttons["Log set"].waitForExistence(timeout: 5), "the log screen never opened")
    }

    /// Taps Log set and waits out the beat, checking what it said when asked.
    private func logSet(expecting beat: String? = nil, line: UInt = #line) {
        let log = app.buttons["Log set"]
        XCTAssertTrue(log.waitForExistence(timeout: 10), "no Log set button", line: line)
        log.tap()
        if let beat {
            if !app.staticTexts[beat].waitForExistence(timeout: 5) {
                // only read the screen when something is already wrong
                let shown = app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " | ")
                XCTFail("the beat did not say \(beat). on screen: \(shown)", line: line)
            }
        }
        // the beat clears itself; tapping it only gets there sooner
        app.tap()
    }

    /// Which lift the log screen is on. The name is a button now, and its
    /// label changes depending on whether there is anything to switch to.
    private func onLift(_ name: String, line: UInt = #line) {
        let plain = app.buttons[name]
        let switchable = app.buttons["\(name). Tap to do a different lift first"]
        XCTAssertTrue(plain.waitForExistence(timeout: 8) || switchable.exists,
                      "not on \(name)", line: line)
    }

    /// The rest screen. It always follows a set that is not the last of the
    /// workout, so a missing one is a failure rather than something to skip.
    private func leaveRest(line: UInt = #line) {
        let done = app.buttons["Done resting"]
        XCTAssertTrue(done.waitForExistence(timeout: 8), "no rest screen", line: line)
        done.tap()
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
