//
// the home screen, driven through the real app.
//
// It has two faces and they ask for different things: before she has agreed
// to a week it asks for one session, and after it shows the plan. The path
// between them is one tap on the empty lifts card, which is the whole point
// of putting the offer there rather than in onboarding. Her reason is not on
// this screen at all any more: it is on the launch screen.

import XCTest

final class HomeTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // the three questions answered, no week agreed to, nothing logged
        app.launchArguments = ["-uitest-skip-opening", "-uitest-reset", "-uitest-onboarded", "-uitest-noweek",
                               "-uitest-hold-beats"]
        app.launch()
    }

    private func still(_ named: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = named
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testWithoutAWeekTheScreenOffersOneSessionAndNotAPlan() {
        XCTAssertTrue(app.staticTexts["Your first workout"].waitForExistence(timeout: 10))
        still("10-home-first-run")

        XCTAssertTrue(app.buttons["Start a quick workout"].exists,
                      "the one action before a week exists is a session with no setup")
        XCTAssertTrue(app.staticTexts["Nothing here yet"].exists)
        XCTAssertFalse(app.buttons["Start workout"].exists,
                       "there is no plan yet, so nothing should offer to start one")
    }

    func testHerReasonIsNotOnTheHomeScreenAnyMore() {
        // it moved to the launch screen, under whether today is a workout day
        // or a rest day, and it is changed from her profile. two copies of it
        // on the screen she opens every day was one too many.
        XCTAssertTrue(app.staticTexts["Your first workout"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["YOU WORK OUT BECAUSE"].exists)
        XCTAssertFalse(app.buttons["change-reason"].exists)
        XCTAssertFalse(app.buttons["add-reason"].exists)
    }

    func testBuildingAWeekTurnsTheOfferIntoAPlan() {
        let offer = app.buttons["build-your-week"]
        XCTAssertTrue(offer.waitForExistence(timeout: 10), "no way through to the week")
        offer.tap()

        XCTAssertTrue(app.staticTexts["Which days can you keep?"].waitForExistence(timeout: 5))
        still("11-your-week")

        // the plan this is about is *today's* plan, so the week she saves has
        // to include today. tapping a fixed day name would switch today off
        // on one weekday in seven, and the screen would correctly show a rest
        // day while the test sat waiting for Start workout.
        let names = ["Sunday", "Monday", "Tuesday", "Wednesday",
                     "Thursday", "Friday", "Saturday"]
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = .current
        let today = app.buttons[names[gregorian.component(.weekday, from: .now) - 1]]
        XCTAssertTrue(today.exists)
        if !today.isSelected { today.tap() }
        app.buttons["Save my week"].tap()

        XCTAssertTrue(app.buttons["Start workout"].waitForExistence(timeout: 10),
                      "agreeing to a week should turn the screen into a plan")
        still("12-home-with-a-plan")
        XCTAssertFalse(app.staticTexts["Nothing here yet"].exists)
        XCTAssertFalse(app.staticTexts["Your first workout"].exists)
    }

    func testTheWeekSheAgreedToSurvivesTheAppClosing() {
        app.buttons["build-your-week"].tap()
        XCTAssertTrue(app.buttons["Save my week"].waitForExistence(timeout: 5))
        app.buttons["Save my week"].tap()
        XCTAssertTrue(app.buttons["Start workout"].waitForExistence(timeout: 10))

        app.terminate()
        app.launchArguments = ["-uitest-skip-opening", "-uitest-hold-beats"]
        app.launch()

        XCTAssertTrue(app.buttons["Start workout"].waitForExistence(timeout: 10),
                      "it asked her to build a week she had already built")
    }
}
