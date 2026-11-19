//
// the week, and what is actually on it.
//
// Before this, every training day was called "Leg day" and had the same two
// lifts on it, whichever day it was. These tests drive the path she takes to
// fix that: the week screen says what each day is, and one tap gets into the
// workout itself.

import XCTest

final class RoutineTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest-skip-opening", "-uitest-reset", "-uitest-onboarded",
                               "-uitest-noweek", "-uitest-hold-beats"]
        app.launch()
    }

    private func still(_ named: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = named
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// The day the test phone is being run on, 0 = Sunday. The fixture week
    /// is placed around today, so today always has a workout on it.
    private var weekday: Int {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = .current
        return gregorian.component(.weekday, from: .now) - 1
    }

    private func openTheWeek() {
        let offer = app.buttons["build-your-week"]
        XCTAssertTrue(offer.waitForExistence(timeout: 10))
        offer.tap()
        XCTAssertTrue(app.staticTexts["Which days can you keep?"].waitForExistence(timeout: 5))
    }

    /// The kind of day is hers to pick, and the name follows it.
    ///
    /// The rules package has had named day types since the port and no screen
    /// ever asked for one, so every day was read off its name and a day she
    /// renamed stopped being a leg day. This is the screen that asks.
    func testTheKindOfDayIsHersToPick() {
        openTheWeek()
        app.buttons["workout-\(weekday)"].tap()

        let picker = app.buttons["day-kind"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5),
                      "there is no way to say what kind of day this is")
        picker.tap()
        app.buttons["Full body"].tap()

        let field = app.textFields["day-name"]
        XCTAssertEqual(field.value as? String, "Full body",
                       "the name did not follow the kind of day she picked")
        XCTAssertTrue(app.staticTexts["A bit of everything, and the one that works on three days a week"]
                        .waitForExistence(timeout: 5),
                      "nothing says what that kind of day is for")

        // and the day can be filled from the kind she just picked, which is
        // the rules package picking out of the real catalogue
        let fill = app.buttons["fill-from-kind"]
        XCTAssertTrue(fill.waitForExistence(timeout: 5),
                      "there is no way to fill the day from what kind of day it is")
        fill.tap()
        XCTAssertTrue(app.staticTexts["Back Squat"].waitForExistence(timeout: 5),
                      "filling a full body day did not put a leg lift on it")

        app.buttons["save-day"].tap()
        XCTAssertTrue(app.buttons["Save my week"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Full body"].exists,
                      "the week did not take the day she just changed")
    }

    /// The default week trains each group once, and says so.
    func testAPushPullLegsWeekSaysWhatItLeavesOut() {
        openTheWeek()
        XCTAssertTrue(app.staticTexts["On this split some muscle groups only get trained once a week. Twice is what the guidance asks for."]
                        .waitForExistence(timeout: 5),
                      "the week says nothing about what its own split costs")
    }

    func testTheWeekSaysWhatEachDayIsAndNotJustWhichDays() {
        openTheWeek()
        XCTAssertTrue(app.staticTexts["YOUR WORKOUTS"].waitForExistence(timeout: 5),
                      "the week is seven circles again, with no workouts on it")
        XCTAssertTrue(app.buttons["workout-\(weekday)"].exists)
        still("30-your-week-with-workouts")
    }

    func testAWorkoutCanBeRenamedAndTheHomeScreenSaysSo() {
        openTheWeek()
        app.buttons["workout-\(weekday)"].tap()

        let field = app.textFields["day-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        still("31-one-workout")

        field.tap()
        let before = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: before.count))
        field.typeText("Chest and arms")
        app.buttons["save-day"].tap()

        XCTAssertTrue(app.buttons["Save my week"].waitForExistence(timeout: 5))
        app.buttons["Save my week"].tap()

        XCTAssertTrue(app.staticTexts["Chest and arms"].waitForExistence(timeout: 10),
                      "the name she gave today never reached the home screen")
        still("32-home-with-her-own-workout")
    }

    func testALiftAddedToADayIsOnTodaysCard() {
        openTheWeek()
        app.buttons["workout-\(weekday)"].tap()
        XCTAssertTrue(app.buttons["add-lift-to-day"].waitForExistence(timeout: 5))
        app.buttons["add-lift-to-day"].tap()

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Deadlift")
        app.buttons["Deadlift"].firstMatch.tap()

        // straight back to the workout: a day has no sets to choose, the
        // rules decide those on the day from what she did last time
        XCTAssertTrue(app.staticTexts["Deadlift"].waitForExistence(timeout: 5))
        app.buttons["save-day"].tap()
        app.buttons["Save my week"].tap()

        XCTAssertTrue(app.staticTexts["Deadlift"].waitForExistence(timeout: 10),
                      "the lift she added is not in today's workout")
    }

    /// Changing the days redraws the week, and it used to redraw it from the
    /// saved profile: a workout she had just edited was thrown away by the
    /// next tap on a circle, without a word.
    func testAWorkoutSheEditedSurvivesChangingTheDays() {
        openTheWeek()
        app.buttons["workout-\(weekday)"].tap()
        XCTAssertTrue(app.buttons["add-lift-to-day"].waitForExistence(timeout: 5))
        app.buttons["add-lift-to-day"].tap()

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Deadlift")
        app.buttons["Deadlift"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Deadlift"].waitForExistence(timeout: 5))
        app.buttons["save-day"].tap()

        // one circle off and straight back on: the week is the same week, and
        // it has been replanned twice in the middle of her editing it
        let other = app.buttons["day-\((weekday + 2) % 7)"]
        XCTAssertTrue(other.waitForExistence(timeout: 5))
        other.tap()
        other.tap()

        app.buttons["Save my week"].tap()
        XCTAssertTrue(app.staticTexts["Deadlift"].waitForExistence(timeout: 10),
                      "the lift she added was thrown away by a tap on a day")
    }

    /// The day she named, off the week and back on. The existing test takes a
    /// different day off, which the planner survived; this takes off the one
    /// carrying the workout. Replanning builds from the days that are on, so
    /// her Monday came back as the app's default Push day with default lifts.
    /// Found by a codex review 2026-11-15.
    func testADayTurnedOffAndBackOnKeepsTheWorkoutShePutOnIt() {
        openTheWeek()
        app.buttons["workout-\(weekday)"].tap()

        let field = app.textFields["day-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        let before = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: before.count))
        field.typeText("Chest and arms")
        app.buttons["save-day"].tap()

        XCTAssertTrue(named("Chest and arms").waitForExistence(timeout: 5),
                      "the rename never reached the week screen, so this test proves nothing")

        let hers = app.buttons["day-\(weekday)"]
        XCTAssertTrue(hers.waitForExistence(timeout: 5))
        hers.tap()
        hers.tap()

        XCTAssertTrue(named("Chest and arms").waitForExistence(timeout: 5),
                      "a day off the week came back as the app's own guess and her workout was gone")
    }

    private func named(_ text: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", text))
            .firstMatch
    }

    /// Everything on the week screen before she touches it is the app talking
    /// to itself, and a guess is allowed to be reconsidered. Cutting the
    /// suggested three days to one should give her a full body day, not the
    /// push day the app had got as far as naming.
    func testTheAppsOwnSplitIsRethoughtWhenSheCutsItDown() {
        openTheWeek()
        keepOnly(weekday)
        XCTAssertTrue(app.staticTexts["Full body"].waitForExistence(timeout: 5),
                      "one day a week and the app still called it half a split")
        still("33-one-day-is-a-full-body-day")
    }

    private func keepOnly(_ keep: Int) {
        let kept = app.buttons["day-\(keep)"]
        XCTAssertTrue(kept.waitForExistence(timeout: 5))
        if !kept.isSelected { kept.tap() }
        for index in 0..<7 where index != keep {
            let circle = app.buttons["day-\(index)"]
            if circle.isSelected { circle.tap() }
        }
    }
}
