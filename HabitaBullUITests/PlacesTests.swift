//
// the three places, and the one rule about them: a workout is not a place.
//
// The bar is attached to each place's own scroll view rather than to the
// navigation stack around it, which is easy to get wrong in a way no unit
// test would catch. These drive the real bar in the real app.

import XCTest

final class PlacesTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest-skip-opening", "-uitest-reset", "-uitest-onboarded", "-uitest-hold-beats"]
        app.launch()
    }

    private func still(_ named: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = named
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testTheBarOpensTheOtherTwoPlacesAndComesBack() {
        XCTAssertTrue(app.buttons["tab-today"].waitForExistence(timeout: 10))
        still("20-home-with-the-bar")

        app.goTo("progress")
        XCTAssertTrue(app.staticTexts["YOUR RECORD"].waitForExistence(timeout: 5),
                      "the middle tab opened nothing")
        still("21-progress")

        app.goTo("profile")
        XCTAssertTrue(app.staticTexts["YOUR WEEK"].waitForExistence(timeout: 5))
        still("22-profile")

        app.goTo("today")
        XCTAssertTrue(app.buttons["Start workout"].waitForExistence(timeout: 5),
                      "no way back to today")
    }

    /// The raised circle is drawn above the bar, and the top of it has to
    /// work: it is the biggest target on the screen and the one people aim at.
    func testTheTopOfTheRaisedCircleIsTappable() {
        let tab = app.buttons["tab-progress"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        // above the button's own box, where the circle sticks out
        // the top of the circle, which is the top of the tab's own row
        tab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        XCTAssertTrue(app.staticTexts["YOUR RECORD"].waitForExistence(timeout: 5),
                      "the visible top of the circle does nothing when tapped")
    }

    func testAWorkoutIsAModeAndHasNoBar() {
        app.buttons["Start workout"].tap()
        XCTAssertTrue(app.buttons["Log set"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["tab-progress"].exists,
                       "somebody between sets was offered three ways to leave")
    }

    /// The record with something in it, which is the state it exists for.
    func testARecordWithWeeksInItCountsThemBack() {
        app.terminate()
        app.launchArguments = ["-uitest-skip-opening", "-uitest-reset", "-uitest-onboarded", "-uitest-history",
                               "-uitest-hold-beats"]
        app.launch()

        app.goTo("progress")
        XCTAssertTrue(app.staticTexts["YOUR RECORD"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["LIFT BY LIFT"].exists,
                      "six logged workouts and nothing to show for them")
        still("23-progress-with-a-record")
    }

    /// Leaving a place and coming back should not throw away what she was in
    /// the middle of typing. Found by an independent review, not by a tester.
    func testAHalfTypedReasonSurvivesALookAtTheRecord() {
        app.goTo("profile")
        let change = app.buttons["change-reason"]
        XCTAssertTrue(change.waitForExistence(timeout: 5))
        change.tap()

        let field = app.textViews["Why you work out"].exists
            ? app.textViews["Why you work out"] : app.textFields["Why you work out"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "the reason never opened for editing")
        field.tap()
        field.typeText(" And my back hurts less.")

        app.goTo("progress")
        XCTAssertTrue(app.staticTexts["YOUR RECORD"].waitForExistence(timeout: 5))
        app.goTo("profile")

        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 5),
                      "coming back closed the editor she was typing in")
        let kept = (field.value as? String) ?? ""
        XCTAssertTrue(kept.contains("back hurts less"),
                      "the half-typed sentence was thrown away, it said: \(kept)")
        still("24-a-reason-being-typed")
    }

    func testTheWeekCanBeChangedFromTheProfile() {
        app.goTo("profile")
        let change = app.buttons["change-week"]
        XCTAssertTrue(change.waitForExistence(timeout: 5))
        change.tap()

        XCTAssertTrue(app.staticTexts["Which days can you keep?"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["tab-progress"].exists,
                       "the week screen is a mode too, not a fourth place")
        app.buttons["Monday"].tap()
        app.buttons["Save my week"].tap()
        XCTAssertTrue(app.buttons["change-week"].waitForExistence(timeout: 5),
                      "saving the week should come back to the profile")
    }
}
