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

    /// The bull is still arriving when the first word exists, so a still taken
    /// then catches him mid-air and out of focus. These stills are the evidence
    /// that nothing is cut off, so they wait for him to land. Only possible at
    /// all because -uitest-hold-opening is holding the screen open.
    private func letItLand() {
        Thread.sleep(forTimeInterval: 1.6)
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
        letItLand()
        still("01-opening")

        // no label over it: the quotation marks are what say it is hers
        XCTAssertFalse(app.staticTexts["YOU WORK OUT BECAUSE"].exists)
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
        // no hold: the real timing, which has to end by itself.
        //
        // What it waits on is the launch screen going, not the home screen
        // arriving. The home screen is behind it the whole time it is up, so a
        // button on it exists from the first moment and waiting for one only
        // proves the app launched. This used to pass for that reason: the query
        // took longer than the screen did.
        app.launchArguments = ["-uitest-reset", "-uitest-onboarded", "-uitest-hold-beats"]
        app.launch()

        let gone = expectation(for: NSPredicate(format: "exists == false"),
                               evaluatedWith: app.otherElements["opening"])
        wait(for: [gone], timeout: 15)

        XCTAssertTrue(app.buttons["Start workout"].waitForExistence(timeout: 10),
                      "the launch screen left and took the app with it")
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
        letItLand()
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
        letItLand()
        still("04-opening-biggest-text")
        XCTAssertTrue(app.staticTexts["\u{201C}It clears my head.\u{201D}"].exists)
    }

    func testTheOpeningWakesUpRatherThanSpinning() {
        // the bull is motion now, so one still cannot say whether it works.
        // four of them are the evidence: he falls in, he lands and takes it
        // through his body, he comes back up with the words settled under him,
        // and then he is still, because it finishes rather than going again.
        //
        // -uitest-slow-opening stretches the same curves over four times the
        // clock. Without it the reveal is over before the runner hands control
        // back, so every still would be the same settled screen.
        app.launchArguments = ["-uitest-reset", "-uitest-onboarded",
                               "-uitest-hold-opening", "-uitest-slow-opening",
                               "-uitest-hold-beats"]
        app.launch()
        var frames = 1

        // the runner hands control back about a second in, which at this tempo
        // is before the bull has moved, so the first still is waited for. the
        // gaps are uneven because the beats are: three of them land in the
        // first half of the reveal and the last still is the screen at rest
        Thread.sleep(forTimeInterval: 0.5)
        for gap in [0.6, 0.45, 1.6, 0] {
            still("05-opening-frame\(frames)")
            frames += 1
            Thread.sleep(forTimeInterval: gap)
        }
        XCTAssertTrue(app.staticTexts["Workout day"].waitForExistence(timeout: 20),
                      "the reveal is not allowed to leave before it is read")
    }

    func testAFirstRunNeverSeesIt() {
        // nothing has been said yet, so there is nothing true to put on it
        app.launchArguments = ["-uitest-reset", "-uitest-hold-beats"]
        app.launch()

        XCTAssertTrue(app.textFields["Your name"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.otherElements["opening"].exists)
    }
}
