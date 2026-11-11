//
// the first run, driven through the real app.
//
// three screens stand between opening the app for the first time and the
// first set, and every one of them can be skipped. what these check is that
// skipping costs nothing, that answering is kept, and that the app never asks
// twice.

import XCTest

final class OnboardingTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // no profile and no history: a phone that has never run the app
        app.launchArguments = ["-uitest-reset", "-uitest-hold-beats"]
        app.launch()
    }

    func testTheAppOpensOnTheWelcomeScreenAndNotOnAWorkout() {
        XCTAssertTrue(app.staticTexts["HabitaBull"].waitForExistence(timeout: 10),
                      "the first run did not open on Welcome")
        XCTAssertFalse(app.buttons["Start a quick workout"].exists,
                       "Today is behind onboarding, not beside it")
    }

    /// A still of whatever is on screen, kept with the run.
    ///
    /// Three screens nobody sees twice are the easiest thing in the app to
    /// break without noticing, and a failure that hands back a picture is a
    /// failure you can read.
    private func still(_ named: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = named
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testAnsweringAllThreeQuestionsLandsOnTodayWithHerWordsOnIt() {
        let name = app.textFields["Your name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        still("01-welcome")
        name.tap()
        // return rather than the button: the keyboard is over the button and
        // the field already advances on submit
        name.typeText("Lucy\n")

        // the reason, from the suggestions rather than the keyboard
        let reason = app.buttons["It clears my head"]
        XCTAssertTrue(reason.waitForExistence(timeout: 5), "no reason to start from")
        reason.tap()
        // wait for the chip to read as chosen before the still: tapping it
        // leaves a press state behind for a moment, and a picture taken
        // inside that moment is a picture of a button being pressed
        wait(for: [expectation(for: NSPredicate(format: "isSelected == true"),
                               evaluatedWith: reason)], timeout: 3)
        still("02-why-you-lift")
        app.buttons["Continue"].tap()

        // by identifier: the option reads as one thing to VoiceOver, so its
        // name is the label and the hint together
        let pace = app.buttons["rest-60"]
        XCTAssertTrue(pace.waitForExistence(timeout: 5), "the rest step never opened")
        pace.tap()
        wait(for: [expectation(for: NSPredicate(format: "isSelected == true"),
                               evaluatedWith: pace)], timeout: 3)
        still("03-how-long-you-rest")
        app.buttons["Let's go"].tap()

        XCTAssertTrue(app.buttons["Start a quick workout"].waitForExistence(timeout: 10),
                      "finishing the questions did not reach Today")
        still("04-today-first-run")
        XCTAssertTrue(app.staticTexts["Your first workout"].exists,
                      "the first run should ask for a session, not show a plan")
        XCTAssertTrue(app.staticTexts["Good to see you, Lucy."].exists,
                      "her name was asked for and never used")
    }

    func testSkippingTheQuestionsStillGetsYouToAWorkout() {
        app.buttons["Continue"].tap()           // past the name, typing nothing
        app.buttons["Skip"].tap()               // and past the reason

        XCTAssertTrue(app.buttons["Start a quick workout"].waitForExistence(timeout: 10),
                      "skipping a question should cost nothing")
        XCTAssertFalse(app.staticTexts["Good to see you, ."].exists,
                       "nobody is greeted by an empty name")
    }

    func testTheAppNeverAsksTwice() {
        app.buttons["Continue"].tap()
        app.buttons["Skip"].tap()
        XCTAssertTrue(app.buttons["Start a quick workout"].waitForExistence(timeout: 10))

        // the same phone, opened again. no reset this time, so whatever was
        // saved on the first run is what the second one reads
        app.terminate()
        app.launchArguments = ["-uitest-hold-beats"]
        app.launch()

        XCTAssertTrue(app.buttons["Start a quick workout"].waitForExistence(timeout: 10),
                      "it asked the three questions a second time")
        XCTAssertFalse(app.staticTexts["Welcome to"].exists)
    }
}
