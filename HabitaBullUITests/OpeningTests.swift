//
// the launch screen, through the real app.
//
// The suites about everything else skip it with -uitest-skip-opening, so this
// is the one place it is actually exercised: what it says, that her own words
// are on it, and that it gets out of the way on its own.

import XCTest

final class OpeningTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func still(_ named: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = named
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testTheAppOpensOnWhetherTodayIsAWorkoutDayOrARestDay() {
        // held up so the test can read it rather than race it
        app.launchArguments = ["-uitest-reset", "-uitest-onboarded",
                               "-uitest-hold-opening", "-uitest-hold-beats"]
        app.launch()

        let workout = app.staticTexts["Workout day"]
        let rest = app.staticTexts["Rest day"]
        XCTAssertTrue(workout.waitForExistence(timeout: 10) || rest.exists,
                      "the launch screen has to say which kind of day this is")
        still("01-opening")

        XCTAssertTrue(app.staticTexts["YOU WORK OUT BECAUSE"].exists)
        XCTAssertTrue(app.staticTexts["\u{201C}It clears my head.\u{201D}"].exists,
                      "her own words, on the screen where she decides whether to go")
    }

    func testATapGoesStraightThrough() {
        app.launchArguments = ["-uitest-reset", "-uitest-onboarded",
                               "-uitest-hold-opening", "-uitest-hold-beats"]
        app.launch()
        XCTAssertTrue(app.otherElements["opening"].waitForExistence(timeout: 10))
        app.otherElements["opening"].tap()

        XCTAssertTrue(app.buttons["Start workout"].waitForExistence(timeout: 10),
                      "nobody should have to wait out a splash screen")
    }

    func testItLeavesOnItsOwn() {
        // no hold: the real timing, which has to end by itself
        app.launchArguments = ["-uitest-reset", "-uitest-onboarded", "-uitest-hold-beats"]
        app.launch()

        XCTAssertTrue(app.buttons["Start workout"].waitForExistence(timeout: 15),
                      "the launch screen stayed up")
        XCTAssertFalse(app.staticTexts["Workout day"].exists,
                       "it should be gone, not sitting behind the home screen")
    }

    func testARestDayReadsTheSameOnBothScreens() {
        // a week with today left out of it. the splash and the screen behind
        // it come from one rule, and this is the test that says so out loud.
        app.launchArguments = ["-uitest-reset", "-uitest-onboarded", "-uitest-restday",
                               "-uitest-hold-opening", "-uitest-hold-beats"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Rest day"].waitForExistence(timeout: 10))
        still("02-opening-rest-day")
        app.otherElements["opening"].tap()

        XCTAssertTrue(app.buttons["Train anyway"].waitForExistence(timeout: 10),
                      "a day off is not a locked door")
        still("03-home-rest-day")
        XCTAssertTrue(app.staticTexts["Rest day"].exists,
                      "the home screen went back to naming a workout")
        XCTAssertFalse(app.buttons["Start workout"].exists)
        XCTAssertFalse(app.staticTexts["TODAY'S LIFTS"].exists,
                       "nothing is on today, so there is nothing to list")
    }

    func testTheBiggestTextStillFitsOnIt() {
        // the whole screen is one stack, so at an accessibility size it used
        // to cut the headline to "Workout..." and her sentence off halfway.
        // it scrolls now. a11y labels do not show truncation, so the still is
        // the evidence here and the assertions only prove it is all there.
        app.launchArguments = ["-uitest-reset", "-uitest-onboarded",
                               "-uitest-hold-opening", "-uitest-hold-beats",
                               "-UIPreferredContentSizeCategoryName",
                               "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Workout day"].waitForExistence(timeout: 10))
        still("04-opening-biggest-text")
        XCTAssertTrue(app.staticTexts["\u{201C}It clears my head.\u{201D}"].exists)
    }

    func testAFirstRunNeverSeesIt() {
        // nothing has been said yet, so there is nothing true to put on it
        app.launchArguments = ["-uitest-reset", "-uitest-hold-beats"]
        app.launch()

        XCTAssertTrue(app.textFields["Your name"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.otherElements["opening"].exists)
    }
}
