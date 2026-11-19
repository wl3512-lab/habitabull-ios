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

    /// A reset really is a reset.
    ///
    /// This class asks for a clean slate and then takes the log screen's
    /// opening half for granted. Which half it opens on is `@AppStorage`, and
    /// `-uitest-reset` used to leave that alone, so one test in another class
    /// that tapped "Load the bar" put every test that ran after it on the
    /// plates. Three tests here failed that way on 2026-11-17, all of them
    /// about typing a weight, none of them about anything that had changed.
    ///
    /// Worth a test of its own because the failure looks like a bug in the
    /// thing being tested, lands in a class that did nothing wrong, and only
    /// shows up in a full run.
    func testAResetForgetsWhichHalfOfTheLogScreenSheWasLastOn() {
        // Leave the app on the plates by tapping the switch, the way she
        // would. The first version of this handed `-loadTheBar YES` to the
        // launch, and a launch argument writes into the argument domain,
        // which iOS throws away when the process ends. Nothing was ever
        // saved, so the relaunch below found the default either way and the
        // test passed with the whole reset taken out.
        // Found by a codex audit 2026-11-17.
        // https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/UserDefaults/AboutPreferenceDomains/AboutPreferenceDomains.html
        start()
        let plates = app.buttons["Load the bar"]
        XCTAssertTrue(plates.waitForExistence(timeout: 10),
                      "no switch between the two halves of the log screen")
        plates.tap()
        XCTAssertTrue(app.buttons["Add one 45 pound plate to each side"].waitForExistence(timeout: 10),
                      "could not get the app onto the plates to begin with")

        // that it survives a relaunch at all, which is this test's positive
        // control: without it, a reset that did nothing would be
        // indistinguishable from a preference that was never saved.
        app.terminate()
        app.launchArguments = ["-uitest-skip-opening", "-uitest-onboarded", "-uitest-hold-beats"]
        app.launch()
        // no reset here, on purpose: that is the whole point of this half.
        // The workout from above is still open, so Today offers to continue
        // it rather than to start one, and `start` waits for a button that
        // is not on the screen.
        let carryOn = app.buttons["Continue workout"]
        XCTAssertTrue(carryOn.waitForExistence(timeout: 30),
                      "Today never came back after the relaunch")
        carryOn.tap()
        XCTAssertTrue(app.buttons["Add one 45 pound plate to each side"].waitForExistence(timeout: 10),
                      "the choice of half did not survive a relaunch, so there is nothing here "
                      + "for a reset to forget and the rest of this test proves nothing")

        // and now ask for a clean slate, saying nothing about which half
        app.terminate()
        app.launchArguments = ["-uitest-skip-opening", "-uitest-reset", "-uitest-onboarded",
                               "-uitest-hold-beats"]
        app.launch()
        start()
        XCTAssertTrue(app.buttons["Increase Weight"].waitForExistence(timeout: 10),
                      "a reset left the log screen on the plates, so every test after this one "
                      + "is looking at a screen it did not ask for")
    }

    /// Tapping a logged set to redo it does not take it off her record.
    ///
    /// It used to mark the set not-done in the store and save that straight
    /// away, so a correction she had not finished was already a fact about
    /// the workout: put the phone down in the middle of one and the set she
    /// had done came back as one she had not, gone from her totals and out of
    /// what the next session is planned from. Found by a codex audit
    /// 2026-11-15.
    func testRedoingALoggedSetCorrectsThatSetAndNotTheNextOne() {
        start()
        logSet(expecting: "New lift")
        leaveRest()

        let logged = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Set 1, logged")).firstMatch
        XCTAssertTrue(logged.waitForExistence(timeout: 10), "the first set never read as logged")

        logged.tap()

        // it is still on her record while she is in the middle of redoing it
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Set 1, logged")).firstMatch
            .waitForExistence(timeout: 5),
            "tapping a set to redo it took it off her record before she had redone it")

        // and logging now fixes the set she tapped rather than adding another.
        // the first version of this test stopped at the line above, which the
        // broken version passed: nothing was written either way, and the
        // correction was being thrown away in the same gesture that started it
        logSet()
        leaveRest()

        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Set 2, not logged")).firstMatch
            .waitForExistence(timeout: 10),
            "redoing set 1 logged a new set instead of correcting the one she tapped")
    }

    /// Undo belongs to the set she is on.
    ///
    /// The editor stays on screen while she picks a different set to correct,
    /// and the trail of weights Undo walks back along is held by the plate
    /// view, so it went with it. Load a plate on the third set, tap the first
    /// set to fix a typo in it, press Undo, and the first set took the third
    /// set's weight. She would have to know the bar in front of her to catch
    /// it. Found by a codex audit 2026-11-17, reproduced here first.
    func testUndoDoesNotCarryAWeightFromOneSetToAnother() {
        app.terminate()
        app.launchArguments += ["-loadTheBar", "YES"]
        app.launch()
        start()

        let total = app.staticTexts["plate-total"]
        let fortyFive = app.buttons["Add one 45 pound plate to each side"]
        let five = app.buttons["Add one 5 pound plate to each side"]
        XCTAssertTrue(fortyFive.waitForExistence(timeout: 30), "the plate picker never opened")

        // set one at 135: a forty-five a side on the bar
        fortyFive.tap()
        XCTAssertEqual(total.label, "135", "a 45 a side on a 45 lb bar is 135")
        logSet(expecting: "New lift")
        leaveRest()

        // set two at 145, so that the two sets are not the same number and
        // the wrong answer is tellable from the right one
        five.tap()
        XCTAssertEqual(total.label, "145")
        logSet()
        leaveRest()

        // and on the third she puts another five on, which is the trail
        five.tap()
        XCTAssertEqual(total.label, "155")

        // then goes back to fix the first set
        let first = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Set 1, logged")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10), "the first set never read as logged")
        first.tap()
        XCTAssertEqual(total.label, "135", "correcting the first set did not load its weight")

        app.buttons["Remove last plate"].tap()
        XCTAssertNotEqual(total.label, "155",
                          "Undo on the first set put the third set's weight on the bar")
        XCTAssertNotEqual(total.label, "145",
                          "Undo on the first set put another set's weight on the bar")
        // with no trail of its own, Undo takes the outer plate off, which is
        // how a bar is actually unloaded: 135 back to the bare bar
        XCTAssertEqual(total.label, "45",
                       "Undo with no plates of her own on this set should take the outer "
                       + "plate off the bar")
    }

    /// And it does not cross sets that weigh the same.
    ///
    /// The first fix watched the weight: a weight this view did not write is
    /// a different set, so drop the trail. A codex audit 2026-11-17 found the
    /// hole in that the same day. She can be sent to a set that weighs what
    /// the last one did, and then nothing changes and nothing is dropped.
    /// 155, then 145, then a five a side on the third set to reach 155 again,
    /// then back to the first set to fix it: the weight does not move, so the
    /// trail from the third set survived and Undo gave the first set 145.
    /// The view is told which set it is on now.
    func testUndoDoesNotCarryAWeightFromASetThatWeighedTheSame() {
        app.terminate()
        app.launchArguments += ["-loadTheBar", "YES"]
        app.launch()
        start()

        let total = app.staticTexts["plate-total"]
        let fortyFive = app.buttons["Add one 45 pound plate to each side"]
        let ten = app.buttons["Add one 10 pound plate to each side"]
        let five = app.buttons["Add one 5 pound plate to each side"]
        let undo = app.buttons["Remove last plate"]
        XCTAssertTrue(fortyFive.waitForExistence(timeout: 30), "the plate picker never opened")

        // set one at 155
        fortyFive.tap()
        ten.tap()
        XCTAssertEqual(total.label, "155")
        logSet(expecting: "New lift")
        leaveRest()

        // set two at 145: the outer ten off, a five on
        undo.tap()
        XCTAssertEqual(total.label, "135", "Undo on a fresh set takes the outer plate off")
        five.tap()
        XCTAssertEqual(total.label, "145")
        logSet()
        leaveRest()

        // the third set back up to 155, which is what the first one weighs
        five.tap()
        XCTAssertEqual(total.label, "155")

        let first = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Set 1, logged")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10), "the first set never read as logged")
        first.tap()
        XCTAssertEqual(total.label, "155", "the first set is the one that weighs 155")

        undo.tap()
        XCTAssertNotEqual(total.label, "145",
                          "Undo on the first set put the third set's weight on the bar, and "
                          + "the two sets weighing the same is the only reason it got through")
        XCTAssertEqual(total.label, "135",
                       "with no trail of its own, Undo takes the outer ten off 155")
    }

    /// A name with no letters and no numbers in it is not a lift.
    ///
    /// The id is built out of the letters and numbers in the name, so "!!!"
    /// became the id `custom-`, which shows up in the workout with no name on
    /// it, and any two such names became the same lift.
    /// Found by a codex audit 2026-11-17.
    func testANameOfNothingButPunctuationIsNotOfferedAsALift() {
        let quick = app.buttons["Quick workout instead"]
        XCTAssertTrue(quick.waitForExistence(timeout: 30), "no way into a quick workout")
        quick.tap()
        XCTAssertTrue(app.navigationBars["Add a lift"].waitForExistence(timeout: 10),
                      "the lift picker never opened itself")

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10), "the picker has no search field")
        search.tap()
        search.typeText("!!!")

        let offer = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Add \"'")).firstMatch
        XCTAssertFalse(offer.waitForExistence(timeout: 3),
                       "a name with nothing in it was offered as a lift of her own")

        // and the offer is still there for a name that is one, or this test
        // would pass on a picker that never offers anything
        search.typeText(" Cable Crossover")
        XCTAssertTrue(offer.waitForExistence(timeout: 5),
                      "a real name is no longer offered as a lift of her own")
    }

    /// Swiping the first lift picker away is leaving it.
    ///
    /// A quick workout opens the picker on itself, and backing out of it drops
    /// the empty workout and goes back. That cleanup hung off the Cancel
    /// button, so swiping the sheet down instead left her standing in a
    /// workout with nothing in it: a spacer and End, and no way to add a lift
    /// without leaving the screen and coming back.
    /// Found by a codex review 2026-11-15.
    func testSwipingTheFirstLiftPickerAwayDoesNotStrandHerInAnEmptyWorkout() {
        let quick = app.buttons["Quick workout instead"]
        XCTAssertTrue(quick.waitForExistence(timeout: 30), "no way into a quick workout")
        quick.tap()

        let picker = app.navigationBars["Add a lift"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "the lift picker never opened itself")

        // down, rather than Cancel
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(picker.waitForNonExistence(timeout: 10), "the sheet did not go away")

        XCTAssertTrue(quick.waitForExistence(timeout: 10),
                      "she was left in a workout with nothing in it and no way to put anything in it")
    }

    /// The plate picker, with a bar in her hands.
    ///
    /// 45 and two fives is 65, which the bar shows as a ten a side, because
    /// that is how a bar is actually loaded. Undo went looking for the five it
    /// had written down, found none on the bar, and took the ten off instead:
    /// one tap from 65 to the empty bar, with 55 nowhere on the way.
    /// Found by a codex review 2026-11-15.
    func testUndoingAPlateGoesBackToTheWeightBeforeIt() {
        app.terminate()
        // the plate picker rather than the steppers, which is a saved choice
        app.launchArguments += ["-loadTheBar", "YES"]
        app.launch()
        start()

        let five = app.buttons["Add one 5 pound plate to each side"]
        XCTAssertTrue(five.waitForExistence(timeout: 30), "the plate picker never opened")
        five.tap()
        XCTAssertTrue(app.staticTexts["55"].waitForExistence(timeout: 5), "one five a side is not 55")
        five.tap()
        XCTAssertTrue(app.staticTexts["65"].waitForExistence(timeout: 5), "two fives a side is not 65")

        app.buttons["Remove last plate"].tap()

        XCTAssertTrue(app.staticTexts["55"].waitForExistence(timeout: 5),
                      "undo took the whole ten off instead of the five she had just put on")
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

        let tapToType = app.staticTexts["Weight-number"]
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
        leaveRest()

        // the set bar, which is the app's own account of the set it saved.
        // This used to read "100 lb" anywhere on the screen, and the screen
        // after a logged set is the rest screen, whose weight is the next
        // set's. A store saving something else entirely still plans the next
        // set off what she typed, so the assertion passed on a saved weight
        // of anything at all. Found by a codex audit 2026-11-18.
        assertLogged(set: 1, says: "100 pounds")
    }

    /// The number on the screen is the number that gets logged.
    ///
    /// Weights are accepted in halves, and the rounding happens where the
    /// typing is read. The field was left showing what she typed: 22.3 on
    /// screen over a value of 22.5, and tapping Log set with the keyboard
    /// still up saved a number she had never seen. Typed reps did the same,
    /// 8.5 on screen and 9 in the log.
    /// Found by a codex audit 2026-11-17.
    func testTheNumberOnTheScreenIsTheNumberThatGetsLogged() {
        start()

        app.staticTexts["Weight-number"].tap()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "the weight field never took focus")
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8))
        field.typeText("22.3")

        XCTAssertEqual(field.value as? String, "22.5",
                       "the field is showing a weight the app will not save")

        app.buttons["Log set"].tap()
        app.tap()
        leaveRest()
        assertLogged(set: 1, says: "22.5 pounds")
    }

    /// The bar under the plates belongs to the set she is correcting.
    ///
    /// A weight lighter than her usual bar means a lighter bar: a 30 lb squat
    /// is a 30 lb bar and no plates. That only ever shrank, and nothing put
    /// it back, so correcting a light set changed what the next correction
    /// would do. Log 30, then 120 on a 30 lb bar, then go back: the first set
    /// drops the bar to 30 and the second set keeps it there, so the label
    /// read "30 lb bar" under 120 and Strip set the weight to 30.
    /// Found by a codex audit 2026-11-17.
    func testTheBarUnderThePlatesBelongsToTheSetSheIsCorrecting() {
        // No `-loadTheBar` here. A launch argument lives in the argument
        // domain, which is read before the standard one, so a value handed to
        // the launch cannot be changed by tapping the switch: the screen stays
        // on the steppers however many times the test presses "Load the bar".
        // `-uitest-reset` in setUp already clears the key, so the app opens on
        // the steppers and the tap below is the thing that moves it.
        start()

        // set one: lighter than her usual bar, so it is a bar of its own
        app.staticTexts["Weight-number"].tap()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "the weight field never took focus")
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8))
        field.typeText("30")
        logSet(expecting: "New lift")
        leaveRest()

        // set two: the plates, on that same light bar
        let switchToPlates = app.buttons["Load the bar"]
        XCTAssertTrue(switchToPlates.waitForExistence(timeout: 10),
                      "no switch between the two halves of the log screen")
        switchToPlates.tap()
        XCTAssertTrue(app.buttons["Add one 45 pound plate to each side"].waitForExistence(timeout: 10),
                      "could not get onto the plates at all. on screen: "
                      + app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " | "))
        let total = app.staticTexts["plate-total"]
        XCTAssertTrue(total.waitForExistence(timeout: 10), "the plate loader never opened")
        XCTAssertTrue(app.staticTexts["Bar weight 30 pounds"].exists,
                      "a 30 lb lift is a 30 lb bar")
        app.buttons["Add one 45 pound plate to each side"].tap()
        XCTAssertEqual(total.label, "120", "a 45 a side on a 30 lb bar is 120")
        logSet()
        leaveRest()

        // and then back over both of them, which is the whole point: the bar
        // has to be read fresh from the set she lands on
        let first = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Set 1, logged")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10), "the first set never read as logged")
        first.tap()
        XCTAssertTrue(app.staticTexts["Bar weight 30 pounds"].waitForExistence(timeout: 5),
                      "the 30 lb set is a 30 lb bar")

        let second = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Set 2, logged")).firstMatch
        XCTAssertTrue(second.waitForExistence(timeout: 10), "the second set never read as logged")
        second.tap()
        XCTAssertTrue(app.staticTexts["Bar weight 45 pounds"].waitForExistence(timeout: 5),
                      "the bar stayed where the light set pushed it, so the plate maths under "
                      + "a 120 lb set is fifteen a side out")
        app.buttons["Strip"].tap()
        XCTAssertEqual(total.label, "45",
                       "stripping the bar gave the weight of a bar she is not using")
    }

    /// A rest she ended is not running when the app comes back.
    ///
    /// The rest is saved so that closing the app in the middle of one costs
    /// nothing, which means ending one has to be saved too. The tests about
    /// the rest screen watch the cover close, and it closes either way: the
    /// rest only came back on the next launch, which nothing opened.
    /// Found by a codex audit 2026-11-17.
    func testARestSheEndedIsNotRunningWhenTheAppComesBack() {
        start()
        logSet(expecting: "New lift")
        leaveRest()

        app.terminate()
        // everything it saved, kept: no reset this time
        app.launchArguments = ["-uitest-skip-opening", "-uitest-onboarded", "-uitest-hold-beats"]
        app.launch()

        let back = app.buttons["Continue workout"]
        XCTAssertTrue(back.waitForExistence(timeout: 30),
                      "the workout she was in the middle of was not there")
        back.tap()
        XCTAssertTrue(app.buttons["Log set"].waitForExistence(timeout: 10),
                      "the log screen never opened")
        XCTAssertFalse(app.buttons["Done resting"].exists,
                       "the rest she ended was still running when the app came back")
        XCTAssertFalse(app.staticTexts["Resting"].exists,
                       "the rest she ended was still running when the app came back")
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
        // and up, which is what the button says. Asking only whether the
        // clock moved was answered just as well by a +15s that took fifteen
        // seconds off, and a rest cut short is the failure she would feel.
        // Found by a codex audit 2026-11-17.
        XCTAssertGreaterThan(seconds(after), seconds(before),
                             "+15s moved the clock to \(after) from \(before), which is down")

        // and the rest she just decided she needed has to be the rest she is
        // actually in. The clock on screen is the view's own number: taking
        // the write to the store out of the plus button left this test green
        // while closing the app put her back on the rest she had extended
        // away from. Found by a codex audit 2026-11-18.
        for _ in 0..<3 { longer.tap() }
        app.terminate()
        app.launchArguments = ["-uitest-skip-opening", "-uitest-onboarded", "-uitest-hold-beats"]
        app.launch()
        let carryOn = app.buttons["Continue workout"]
        XCTAssertTrue(carryOn.waitForExistence(timeout: 30), "Today never came back")
        carryOn.tap()

        let resting = app.staticTexts["Resting"]
        XCTAssertTrue(resting.waitForExistence(timeout: 10),
                      "the rest she was in the middle of was gone when the app came back")
        let restored = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES '[0-9]+:[0-9][0-9]'")
        ).firstMatch.label
        // the rest is ninety seconds and she added sixty. Even a slow relaunch
        // leaves well over a hundred on a hundred and fifty, and the rest she
        // never extended would be under ninety by now.
        XCTAssertGreaterThan(seconds(restored), 100,
                             "the app came back on \(restored), which is the rest she had "
                             + "before she asked for a longer one")
    }

    /// A clock read off the screen, as seconds. The rest counts down while the
    /// test reads it, so a longer rest is the only thing worth asserting.
    private func seconds(_ clock: String) -> Int {
        let parts = clock.split(separator: ":").map { Int($0) ?? 0 }
        return parts.count == 2 ? parts[0] * 60 + parts[1] : 0
    }

    /// The buttons and the keyboard set the same number and have to agree.
    /// Typing a weight and then tapping the plus moved the value behind a
    /// field still showing the old text, so the screen said one weight and
    /// the set saved another. Found by the second codex pass, 2026-11-15.
    func testSteppingAWeightSheHasTypedMovesWhatSheCanSee() {
        start()

        app.staticTexts["Weight-number"].tap()
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
        leaveRest()
        assertLogged(set: 1, says: "\(shown) pounds")
    }

    /// The weight on the bar has to be readable without sight.
    ///
    /// The number carried the label "Type Weight instead" and no accessibility
    /// value, so VoiceOver answered "what is the weight?" with the instruction
    /// for replacing it. The plus and minus buttons are named, so she could
    /// move the number by ear and never hear where it had got to.
    /// Found by a codex audit 2026-11-16.
    func testTheWeightOnTheBarCanBeHeard() {
        start()
        XCTAssertTrue(app.buttons["Increase Weight"].waitForExistence(timeout: 10))

        let number = app.staticTexts["Weight-number"]
        XCTAssertTrue(number.waitForExistence(timeout: 10),
                      "VoiceOver has nothing to land on for the weight")
        XCTAssertEqual(number.label, "Weight",
                       "the weight announces itself as \(number.label), not as what it is")

        let before = (number.value as? String) ?? ""
        XCTAssertFalse(before.isEmpty,
                       "the weight says what it is called and never what it is, "
                       + "so she can move the number by ear and never hear it")

        app.buttons["Increase Weight"].tap()
        XCTAssertNotEqual((number.value as? String) ?? "", before,
                          "the number moved and its spoken value did not")
    }

    /// Fixing a set does not move her off the lift she chose next.
    ///
    /// Two faults in one detour, both from the fix that made a finished lift
    /// reachable at all. Tapping a logged set pinned that finished lift as
    /// her chosen one, so logging the correction handed the workout to
    /// whatever came next in the session order rather than the lift she had
    /// picked, and saved the finished lift over her place in the file. And
    /// the switch chooser changed her chosen lift without ending the detour,
    /// so the screen stayed on the finished lift and Log set rewrote it
    /// again. Found by a codex audit 2026-11-18.
    func testFixingASetKeepsTheLiftSheChoseNext() {
        start()
        // a third lift, so there is a choice to lose
        addLift(named: "Hammer Curl")

        goToLift("Back Squat")
        logSet()
        leaveRest()
        logSet()
        leaveRest()
        logSet()
        leaveRest()

        // the squat is done and two lifts are left, so it asks. she picks the
        // one that is not next in the session's order
        let instead = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Start Hammer Curl instead'")).firstMatch
        XCTAssertTrue(instead.waitForExistence(timeout: 8), "it never asked what was next")
        instead.tap()
        onLift("Hammer Curl")

        // back to the squat to fix its first set
        goBackToFinishedSquat()
        onLift("Back Squat")
        let first = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Set 1, logged'")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5), "the logged sets are not there to tap")
        first.tap()

        typeWeight("105")
        app.buttons["Log set"].tap()
        app.tap()

        // the lift she chose, not the one that happens to come next
        onLift("Hammer Curl")

        goBackToFinishedSquat()
        assertLogged(set: 1, says: "105 pounds")

        // and a chooser opened during a fix really does leave the squat
        app.buttons["Back Squat. Tap to do a different lift first"].tap()
        let swap = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Switch to Leg Press'")).firstMatch
        XCTAssertTrue(swap.waitForExistence(timeout: 5), "the switch chooser never opened")
        swap.tap()
        onLift("Leg Press")
    }

    /// The receipt is for the workout she just finished.
    ///
    /// With last night's still open the store's fallback lands on it, which
    /// is right for a set and wrong for a receipt, so the log screen holds
    /// the id of the one it finished. Two store tests cover the fallback and
    /// both hold that id themselves, so the screen could have stopped holding
    /// it and nothing would have gone red.
    /// Found by a codex audit 2026-11-18.
    func testTheReceiptIsForTheWorkoutSheJustFinished() {
        // the same phone, with last night's workout still open on it
        app.terminate()
        app.launchArguments = ["-uitest-skip-opening", "-uitest-reset", "-uitest-onboarded",
                               "-uitest-hold-beats", "-uitest-lastnight"]
        app.launch()

        // last night's is offered back, and she puts it down: it stays open
        // in the file, which is the trap
        let offered = app.buttons["unfinished-card"]
        XCTAssertTrue(offered.waitForExistence(timeout: 30), "last night's workout is not offered back")
        offered.tap()
        app.buttons["End"].tap()

        start()
        logSet()
        leaveRest()
        app.buttons["End"].tap()
        let finish = app.buttons["Finish workout"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5), "End never offered to finish")
        finish.tap()

        XCTAssertTrue(app.staticTexts["First time on Back Squat"].waitForExistence(timeout: 10),
                      "the receipt does not name the workout she just finished")
        XCTAssertFalse(app.staticTexts["First time on Dumbbell Hammer Curl"].exists,
                       "the receipt is for last night's workout, which is still open behind it")
    }

    /// A first day's receipt can be got out of.
    ///
    /// Every lift of a first workout is a first time, and the badges went
    /// into a column as tall as the phone and no taller: ten of them are
    /// longer than the screen on their own padding, so the overflow went on
    /// top of Done and there was nothing to scroll.
    /// Found by a codex audit 2026-11-18.
    func testAFirstDaysReceiptCanBeGotOutOf() {
        // the same phone, with today's workout logged out on ten new lifts
        app.terminate()
        app.launchArguments = ["-uitest-skip-opening", "-uitest-reset", "-uitest-onboarded",
                               "-uitest-hold-beats", "-uitest-firstday"]
        app.launch()

        let carryOn = app.buttons["Continue workout"]
        XCTAssertTrue(carryOn.waitForExistence(timeout: 30), "Today never offered the open workout")
        carryOn.tap()

        let finish = app.buttons["Finish workout"]
        XCTAssertTrue(finish.waitForExistence(timeout: 10), "a workout with every set logged does not offer to finish")
        finish.tap()

        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), "the receipt has no Done on it")

        // ten badges are longer than the phone, so Done is under the fold:
        // what matters is that it can be reached
        let screen = app.windows.firstMatch.frame
        var swipes = 0
        while !(screen.contains(done.frame) && done.isHittable), swipes < 4 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(screen.contains(done.frame) && done.isHittable,
                      "Done sits at \(done.frame) on a \(screen.size) screen after \(swipes) "
                      + "swipes, so the receipt runs off the phone and the way out of it with it")
    }

    /// A weight typed wrong is still hers to fix after she has moved on.
    ///
    /// The lift menu offered only lifts with sets left, and the screen could
    /// not be on a lift with none, so a 195 lb squat typed instead of 95 was
    /// out of reach from the moment she started her next lift. It stayed in
    /// her records, in her best, and in every weight the planner worked out
    /// after it. Found by a codex audit 2026-11-18.
    func testATypoOnALiftSheHasFinishedCanStillBeFixed() {
        start()
        onLift("Back Squat")

        logSet()
        leaveRest()
        logSet()
        leaveRest()
        // the last set of the squat, at a weight she did not mean
        typeWeight("195")
        logSet()
        leaveRest()

        // with one lift left there is nothing to choose, so the workout moves
        // on by itself
        onLift("Leg Press")

        goBackToFinishedSquat()
        onLift("Back Squat")
        assertLogged(set: 3, says: "195 pounds")

        typeWeight("95")
        app.buttons["Log set"].tap()
        app.tap()

        // the fix hands the workout back where it was
        onLift("Leg Press")

        goBackToFinishedSquat()
        assertLogged(set: 3, says: "95 pounds")
        XCTAssertFalse(app.buttons["Set 4, not logged"].exists,
                       "fixing a set added a set to the lift instead")
    }

    /// A space on the end of what she typed does not hide a lift.
    ///
    /// The list filtered on the raw text while the duplicate check trimmed
    /// it, so "Hammer Curl " found nothing (no lift's name carries that
    /// space) and was not offered as a lift of her own either, because
    /// trimmed it is already one. An empty picker for a lift the app ships,
    /// and iOS types that space itself when she takes a predictive
    /// suggestion. Found by a codex audit 2026-11-18.
    func testASpaceOnTheEndOfTheSearchStillFindsTheLift() {
        start()
        openThePicker()
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("Hammer Curl ")

        XCTAssertTrue(app.buttons["Hammer Curl"].waitForExistence(timeout: 5),
                      "a space on the end hid a lift the app ships")
        XCTAssertFalse(app.buttons["Add \"Hammer Curl\" as your own"].exists,
                       "it offered a second Hammer Curl under a different id")
    }

    /// A lift she made herself is still in the picker the week after.
    ///
    /// The list was the bundled library and nothing else, so her own lift was
    /// in the app for exactly one workout: afterwards browsing could not find
    /// it, and searching part of its name offered to make another one under a
    /// different id, which splits one lift's history in two.
    /// Found by a codex audit 2026-11-18.
    func testALiftSheMadeHerselfIsStillInThePickerLater() {
        // the same phone, with last week's workout on it
        app.terminate()
        app.launchArguments = ["-uitest-skip-opening", "-uitest-reset", "-uitest-onboarded",
                               "-uitest-hold-beats", "-uitest-own-lift"]
        app.launch()

        start()
        openThePicker()
        XCTAssertTrue(app.staticTexts["YOUR LIFTS"].waitForExistence(timeout: 5),
                      "her own lifts have no place in the picker")
        XCTAssertTrue(app.buttons["Belt Squat"].exists,
                      "the lift she made last week is not in the list")

        // and part of its name finds it
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("belt")
        XCTAssertTrue(app.buttons["Belt Squat"].waitForExistence(timeout: 5),
                      "searching part of the name does not find her own lift")

        search.typeText(" squat")
        XCTAssertFalse(app.buttons["Add \"belt squat\" as your own"].exists,
                       "typing the name of a lift she already made offered to make it again")
    }

    /// The set bar's own account of a logged set: "Set 1, logged 100 pounds
    /// for 8 reps". The reps are left out of the check so a test about the
    /// weight stays about the weight.
    private func assertLogged(set: Int, says: String, line: UInt = #line) {
        let logged = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Set \(set), logged \(says)")
        ).firstMatch
        if !logged.waitForExistence(timeout: 8) {
            let shown = app.buttons.allElementsBoundByIndex.map(\.label)
                .filter { $0.hasPrefix("Set ") }.joined(separator: " | ")
            XCTFail("set \(set) does not say it logged \(says). the bar says: \(shown)",
                    line: line)
        }
    }

    /// Types a weight, keyboard up and nothing dismissed, which is how she
    /// uses it.
    private func typeWeight(_ pounds: String, line: UInt = #line) {
        let number = app.staticTexts["Weight-number"]
        XCTAssertTrue(number.waitForExistence(timeout: 8), "no weight to tap", line: line)
        number.tap()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5),
                      "the weight field never took focus", line: line)
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8))
        field.typeText(pounds)
    }

    /// The lift menu, and a lift in it that still has sets left.
    private func goToLift(_ name: String, line: UInt = #line) {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Exercise '")).firstMatch.tap()
        let row = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "\(name), ")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "no \(name) in the lift menu", line: line)
        row.tap()
    }

    /// The lift menu, and the squat in it with nothing left to do.
    private func goBackToFinishedSquat(line: UInt = #line) {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Exercise '")).firstMatch.tap()
        let back = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Back Squat, done'")).firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5),
                      "a lift she has finished is not offered, so a set logged wrong on it "
                      + "cannot be reached at all", line: line)
        back.tap()
    }

    /// The add-a-lift sheet, from the lift menu.
    private func openThePicker(line: UInt = #line) {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Exercise '")).firstMatch.tap()
        app.buttons["Add a lift"].tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5),
                      "the lift picker never opened", line: line)
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

    /// The offer to make a lift your own, offered for a lift she already has.
    ///
    /// The picker takes the lifts already in the workout out of its list, and
    /// the offer asked that list whether the name existed. So searching for
    /// the Back Squat she was in the middle of read as "no such lift", and
    /// she was offered it in cyan as a lift of her own. Taking the offer
    /// would have given her a second Back Squat under custom-back-squat: a
    /// lift of its own that loads in fives, with no equipment and none of the
    /// real squat's history behind it.
    ///
    /// Typing the name of one of her own custom lifts produced the opposite
    /// failure from the same line: the same id a second time, which
    /// `addLift` drops on the floor, so the sheet closed and nothing
    /// happened at all. Found by a codex audit 2026-11-16.
    func testALiftSheAlreadyHasIsNotOfferedAsOneOfHerOwn() {
        start()
        openThePicker()
        let search = app.searchFields.firstMatch
        search.tap()
        // a name the library really does not have. "Cable Crossover" was
        // the first try and it is in the library, so the app withheld the
        // offer and was right to.
        search.typeText("Zercher Carry")
        // the positive control, and this test is worth nothing without it: a
        // name that really is new has to produce the offer, or the absence
        // of it below would prove only that the label changed.
        let invent = app.buttons["Add \"Zercher Carry\" as your own"]
        XCTAssertTrue(invent.waitForExistence(timeout: 5),
                      "the offer never appears at all, so looking for it proves nothing")

        // and now a lift that is already in the workout
        clear(search)
        search.typeText("Back Squat")
        XCTAssertFalse(invent.waitForExistence(timeout: 2),
                       "the search text changed and the old offer is still on screen")
        XCTAssertFalse(app.buttons["Add \"Back Squat\" as your own"].exists,
                       "it offered to add a second Back Squat as a lift of her own")
        // nor is it in the list, which is the reason the offer appeared
        XCTAssertFalse(app.buttons["Back Squat"].exists,
                       "a lift already in the workout is offered again")
    }

    /// And the other half: her own lift, typed a second time.
    func testHerOwnLiftIsNotOfferedTwice() {
        start()
        openThePicker()
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("Zercher Carry")
        app.buttons["Add \"Zercher Carry\" as your own"].tap()
        let add = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Add ' AND label CONTAINS 'set'")).firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5), "the sets step never opened")
        add.tap()
        XCTAssertTrue(app.buttons["Zercher Carry, 3 left"].waitForExistence(timeout: 5)
                      || app.staticTexts["Zercher Carry"].waitForExistence(timeout: 5),
                      "the lift of her own never reached the workout")

        openThePicker()
        let again = app.searchFields.firstMatch
        again.tap()
        again.typeText("Zercher Carry")
        XCTAssertFalse(app.buttons["Add \"Zercher Carry\" as your own"].waitForExistence(timeout: 3),
                       "it offered the same id again, which the store drops, so the sheet "
                       + "would have closed on nothing")
    }

    /// A lift she adds at the rack is in that workout next week.
    ///
    /// The plan is where a session's lifts come from, so until the lineup she
    /// trained was carried back onto it, the day rebuilt from its original
    /// shape every week: the lift she added, and the one she swapped out,
    /// were both forgotten by the next session with nothing said about it.
    /// The rule has been in the rules package since the port and nothing in
    /// the app called it. Found by a codex audit 2026-11-18.
    func testTheLiftSheAddsAtTheRackIsInTheWeekAfterwards() {
        // a week first: the lifts live on the workout in her week, and a test
        // phone has answered the three questions without building one
        app.buttons["change-week"].tap()
        XCTAssertTrue(app.buttons["Save my week"].waitForExistence(timeout: 10),
                      "no way through to the week")
        app.buttons["Save my week"].tap()

        start()
        addLift(named: "Hammer Curl")
        logSet()
        // a set that is not the last of the workout is followed by rest, and
        // the toolbar is hidden behind it: End is not on the screen until she
        // is back on the set after it
        leaveRest()

        app.buttons["End"].tap()
        let finish = app.buttons["Finish workout"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5), "End never offered to finish")
        finish.tap()
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), "no receipt after finishing")
        done.tap()

        // and her week holds what she actually trained
        let change = app.buttons["change-week"]
        XCTAssertTrue(change.waitForExistence(timeout: 10), "never got back to Today")
        change.tap()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let weekday = cal.component(.weekday, from: Date()) - 1
        let workout = app.buttons["workout-\(weekday)"]
        XCTAssertTrue(workout.waitForExistence(timeout: 10),
                      "today's workout is not in the week she just saved")
        workout.tap()

        XCTAssertTrue(app.staticTexts["Hammer Curl"].waitForExistence(timeout: 5),
                      "the lift she added at the rack is not in the workout she will open "
                      + "next week: her edit was thrown away when the workout ended")
    }

    /// Putting yesterday's workout down lets today's start.
    ///
    /// Leaving a resumed workout with nothing logged on it closed the screen
    /// and kept the resume: Today went on showing yesterday, "Continue
    /// workout" went back into it, and Start workout was refused because the
    /// store still had an open one. The only way out was to kill the app.
    /// Found by a codex audit 2026-11-18.
    func testWalkingAwayFromYesterdaysWorkoutLetsTodaysStart() {
        app.launchArguments = ["-uitest-skip-opening", "-uitest-reset", "-uitest-onboarded",
                               "-uitest-unfinished", "-uitest-hold-beats"]
        app.launch()

        let offer = app.buttons["unfinished-card"]
        XCTAssertTrue(offer.waitForExistence(timeout: 10),
                      "a workout left open yesterday was not offered back")
        offer.tap()

        let end = app.buttons["End"]
        XCTAssertTrue(end.waitForExistence(timeout: 5), "the log screen never opened")
        // nothing is logged, so there is nothing to confirm: it just closes
        end.tap()

        XCTAssertTrue(app.buttons["Start workout"].waitForExistence(timeout: 10),
                      "she put yesterday down and today would not start: the home screen "
                      + "is still offering to continue a workout from another day")
    }

    private func openThePicker() {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Exercise '")).firstMatch.tap()
        app.buttons["Add a lift"].tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5),
                      "the lift picker never opened")
    }

    /// Empty a search field. Selecting all and typing over it, because the
    /// clear button is only there while the field has focus and a tap on it
    /// is a tap on a moving target.
    private func clear(_ field: XCUIElement) {
        let text = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: text.count))
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
