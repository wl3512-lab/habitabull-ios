//
// the goal, and the home screen it reframes.
//
// The home screen used to be a date, a day name, two lifts, two buttons and
// seven circles, with the bottom half of the phone empty. These tests are
// about what fills it: the workout with its working weights in one card, the
// week with the streak beside it, the goal, and the last day she trained.

import XCTest

final class GoalTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // a phone that has been used: six sessions, a week agreed to, no goal
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

    func testTheDayComesFirstAndThenTheProof() {
        XCTAssertTrue(app.buttons["Start workout"].waitForExistence(timeout: 10))
        still("20-home-the-day-then-the-proof")

        // the plan says what is going on the bar, not just the set shape
        XCTAssertTrue(app.staticTexts["Back Squat"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'lb'"))
                        .firstMatch.exists,
                      "the plan has to say the weight: that is the reason to read it")

        // and the evidence under it
        XCTAssertTrue(app.buttons["set-a-goal"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH[c] 'Last time'"))
                        .firstMatch.exists,
                      "the last day she trained is the shortest honest receipt")
    }

    func testTheWeekIsOneTapAwayFromTheDayItNames() {
        XCTAssertTrue(app.buttons["change-week"].waitForExistence(timeout: 10))
        app.buttons["change-week"].tap()
        XCTAssertTrue(app.staticTexts["Which days can you keep?"].waitForExistence(timeout: 5))
    }

    func testSettingAGoalPutsItOnTodayAndOnProgress() {
        let offer = app.buttons["set-a-goal"]
        XCTAssertTrue(offer.waitForExistence(timeout: 10))
        offer.tap()

        XCTAssertTrue(app.staticTexts["What are you working towards?"].waitForExistence(timeout: 5))
        // nothing to save before a lift is picked
        XCTAssertFalse(app.buttons["goal-save"].exists)

        app.buttons["goal-lift"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Back Squat")
        app.buttons["Back Squat"].firstMatch.tap()

        // picking the lift is the whole picker: a goal has no sets to choose
        XCTAssertFalse(app.staticTexts["Sets"].exists)
        XCTAssertTrue(app.buttons["goal-save"].waitForExistence(timeout: 5))
        still("21-goal-screen")

        // eight weeks is already the standing answer, so saving is one tap
        XCTAssertTrue(app.buttons["goal-weeks-8"].isSelected,
                      "the screen should open on an answer, not on a blank")
        app.buttons["goal-save"].tap()

        let row = app.buttons["goal-row"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "the goal never reached the home screen")
        still("22-home-with-a-goal")

        // and the same goal on the screen that is about measuring
        app.buttons["tab-progress"].tap()
        XCTAssertTrue(app.buttons["goal-row"].waitForExistence(timeout: 10))
        still("23-progress-with-a-goal")
    }

    func testAGoalCanBeTakenBackOff() {
        app.buttons["set-a-goal"].tap()
        app.buttons["goal-lift"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Deadlift")
        app.buttons["Deadlift"].firstMatch.tap()
        app.buttons["goal-save"].tap()
        XCTAssertTrue(app.buttons["goal-row"].waitForExistence(timeout: 10))

        app.buttons["goal-row"].tap()
        XCTAssertTrue(app.buttons["goal-remove"].waitForExistence(timeout: 5))
        app.buttons["goal-remove"].tap()

        XCTAssertTrue(app.buttons["set-a-goal"].waitForExistence(timeout: 10),
                      "removing the goal should put the offer back")
    }
}
