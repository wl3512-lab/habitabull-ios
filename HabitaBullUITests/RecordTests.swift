//
// the record, on a phone that has been used for a couple of months.
//
// Six scattered days cannot have a pattern in them, so these run on
// -uitest-pattern: ten weeks of Wednesdays and Saturdays with three weeks
// missing out of the middle. Everything this screen can say about her needs
// that much history before it is allowed to say it.

import XCTest

final class RecordTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest-skip-opening", "-uitest-reset", "-uitest-onboarded",
                               "-uitest-pattern", "-uitest-hold-beats"]
        app.launch()
        app.buttons["tab-progress"].tap()
        XCTAssertTrue(app.staticTexts["YOUR RECORD"].waitForExistence(timeout: 10))
    }

    private func still(_ named: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = named
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testItNamesTheDaySheKeepsTurningUpOn() {
        XCTAssertTrue(app.staticTexts["You show up on Wednesdays."].exists,
                      "eight Wednesdays and the screen still led with a count")
        XCTAssertTrue(app.staticTexts["Your most reliable day, 8 days in. Protect it."].exists)
        still("50-the-record-names-her-day")
    }

    func testComebacksAreCountedAndTheReasonSaidOnce() {
        XCTAssertTrue(app.staticTexts["1 comeback"].exists,
                      "three weeks off and back is a comeback, and the only one here")
        XCTAssertTrue(app.staticTexts["Counted on purpose. Coming back is the skill."].exists)
    }

    func testTheGridSaysWhatItsColoursMean() {
        for key in ["Trained", "Comeback", "Today"] {
            XCTAssertTrue(app.staticTexts[key].exists, "the grid never says what \(key) looks like")
        }
    }

    /// Swipes until it is on screen, because a scroll view only hands the
    /// test runner what is rendered: a card below the fold is a card whose
    /// contents are not in the tree yet.
    @discardableResult
    private func reach(_ element: XCUIElement, tries: Int = 5) -> Bool {
        for _ in 0..<tries {
            if element.exists && element.isHittable { return true }
            app.swipeUp()
        }
        return element.exists && element.isHittable
    }

    func testEveryLiftSheHasDoneGetsItsOwnLine() {
        let squat = app.otherElements["lift-Back Squat"]
        XCTAssertTrue(reach(squat), "no line for the lift she has done most")
        XCTAssertTrue(app.otherElements["lift-Leg Press"].exists)

        // the card header carries where she is now and what she has added
        XCTAssertTrue(squat.staticTexts["142.5 lb"].exists)
        XCTAssertTrue(squat.staticTexts["+47.5"].exists, "ten weeks of lifting and nothing gained")
        // and the line says what it is drawn from
        XCTAssertTrue(squat.staticTexts["15 days"].exists)
        still("51-lift-by-lift")
    }

    func testOneGlanceReachesTheWholeRecord() {
        // the lines are the bottom of this screen, and a screen she cannot
        // scroll to the end of on a phone is a screen that stops at the grid
        app.swipeUp()
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["LIFT BY LIFT"].exists)
        still("52-the-record-end-to-end")
    }
}
