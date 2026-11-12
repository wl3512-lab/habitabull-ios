//
// the month, and the day behind it.
//
// The grid used to be a picture of her attendance with nothing behind it:
// twelve squares she could count but not open. These tests drive the two ways
// in, the grid and the last time row, and the way back through the months.

import XCTest

final class DayTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest-skip-opening", "-uitest-reset", "-uitest-onboarded",
                               "-uitest-history", "-uitest-hold-beats"]
        app.launch()
    }

    private func still(_ named: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = named
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testTheLastTimeRowOpensThatDay() {
        let row = app.buttons["last-time"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()

        XCTAssertTrue(app.staticTexts["THAT DAY"].waitForExistence(timeout: 5),
                      "the last time row led nowhere")
        XCTAssertTrue(app.staticTexts["Leg day"].exists)
        XCTAssertTrue(app.staticTexts["Back Squat"].exists)
        still("40-a-day-read-back")
    }

    func testADayOnTheGridOpensTheSameScreen() {
        app.buttons["tab-progress"].tap()
        XCTAssertTrue(app.staticTexts["YOUR RECORD"].waitForExistence(timeout: 10))
        still("41-progress-with-the-month")

        // the seeded history is the last fortnight, which on the first of a
        // month is entirely in the month before. page back once rather than
        // assume today's grid has anything on it
        let trained = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'day-20'"))
        if trained.count == 0 { app.buttons["month-back"].tap() }
        XCTAssertGreaterThan(trained.count, 0, "no day on the grid opens anything")
        trained.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["THAT DAY"].waitForExistence(timeout: 5))
    }

    func testTheMonthBeforeCanBeLookedAtAndTheOneAfterCannot() {
        app.buttons["tab-progress"].tap()
        let back = app.buttons["month-back"]
        XCTAssertTrue(back.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["month-forward"].isEnabled,
                       "there is nothing in next month to look at")

        back.tap()
        XCTAssertTrue(app.buttons["month-forward"].isEnabled)
        still("42-the-month-before")
    }
}
