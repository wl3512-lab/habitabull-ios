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

    /// The home screen and the day it links to name the same best set.
    ///
    /// Three screens read one session and each names her best set of it. At
    /// equal weights the day card and the chart take the one with more reps;
    /// the home screen took whichever it met first, so a day of 135 for 5 and
    /// then 135 for 8 read as "135 lb x 5" on the home screen and "135 lb x
    /// 8" one tap later. Found by a codex audit 2026-11-17.
    func testTheHomeRowAndTheDayNameTheSameBestSet() {
        app.terminate()
        app.launchArguments = ["-uitest-skip-opening", "-uitest-reset", "-uitest-onboarded",
                               "-uitest-tie", "-uitest-hold-beats"]
        app.launch()

        let row = app.buttons["last-time"]
        XCTAssertTrue(row.waitForExistence(timeout: 20), "no last time row to read")
        // the whole row is one label, so the set has to be read out of it
        // rather than looked for as a line of its own.
        XCTAssertTrue(row.label.contains("135 lb \u{00D7} 8"),
                      "the home screen named a set that is not her best one: the row said "
                      + "\(row.label)")
        XCTAssertFalse(row.label.contains("135 lb \u{00D7} 5"),
                       "the home screen named the lighter effort of two at one weight: "
                       + "\(row.label)")

        row.tap()
        XCTAssertTrue(app.staticTexts["THAT DAY"].waitForExistence(timeout: 5),
                      "the last time row led nowhere")
        let onTheDay = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '135 lb \u{00D7} 8'")).firstMatch
        XCTAssertTrue(onTheDay.waitForExistence(timeout: 5),
                      "the day the home row links to names a different best set")
        still("41-one-best-set-two-screens")
    }

    func testADayOnTheGridOpensTheSameScreen() {
        app.goTo("progress")
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
        // months of it rather than a fortnight, so the month before today's
        // has days on its grid to read. The fortnight this class runs on is
        // all in one month, and a grid with nothing on it cannot say which
        // month it is drawing. Found by a codex audit 2026-11-18.
        app.terminate()
        app.launchArguments = ["-uitest-skip-opening", "-uitest-reset", "-uitest-onboarded",
                               "-uitest-pattern", "-uitest-hold-beats"]
        app.launch()

        app.goTo("progress")
        let back = app.buttons["month-back"]
        XCTAssertTrue(back.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["month-forward"].isEnabled,
                       "there is nothing in next month to look at")

        // the month itself has to move. Both buttons read `monthsBack`, so a
        // grid that ignored it would still enable the forward arrow and this
        // test would not notice. Found by a codex audit 2026-11-18.
        let heading = app.staticTexts["month-name"]
        XCTAssertTrue(heading.waitForExistence(timeout: 5), "the grid never says which month")
        let thisMonth = heading.label

        // and the days under the heading have to move with it. The heading
        // and the grid read the same `monthsBack`, so a grid that ignored it
        // would page the words and leave the squares where they were, and
        // every assertion in this test would still pass. Only trained days
        // carry a date, which is why this runs on the long seed.
        // Found by a codex audit 2026-11-18.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        func grid() -> [String] {
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'day-20'"))
                .allElementsBoundByIndex.map(\.identifier)
        }
        func monthPrefix(_ monthsBack: Int) -> String {
            let when = cal.date(byAdding: .month, value: -monthsBack, to: Date()) ?? Date()
            let parts = cal.dateComponents([.year, .month], from: when)
            return String(format: "day-%04d-%02d-", parts.year ?? 0, parts.month ?? 0)
        }
        XCTAssertTrue(grid().allSatisfy { $0.hasPrefix(monthPrefix(0)) },
                      "this month's grid is showing days from another month: \(grid())")

        back.tap()
        XCTAssertTrue(app.buttons["month-forward"].isEnabled)
        XCTAssertNotEqual(heading.label, thisMonth,
                          "paging back left the grid on \(heading.label)")
        let before = grid()
        XCTAssertFalse(before.isEmpty,
                       "nothing on the month before's grid, so there is nothing to check")
        XCTAssertTrue(before.allSatisfy { $0.hasPrefix(monthPrefix(1)) },
                      "the heading paged back and the squares did not: \(before)")
        still("42-the-month-before")

        app.buttons["month-forward"].tap()
        XCTAssertEqual(heading.label, thisMonth, "coming forward again landed somewhere else")
        XCTAssertFalse(app.buttons["month-forward"].isEnabled)
    }

    /// A machine's help is not her best set.
    ///
    /// On an assisted lift the weight is counterweight: the bigger it is, the
    /// less she lifted. The home row ranked every logged set by weight alone,
    /// so 185 lb of help beat a 135 lb squat and the one line the screen has
    /// for the day named the easiest thing in it.
    /// Found by a codex audit 2026-11-17.
    func testTheHomeRowDoesNotCallAMachinesHelpHerBestSet() {
        app.terminate()
        app.launchArguments = ["-uitest-skip-opening", "-uitest-reset", "-uitest-onboarded",
                               "-uitest-tie", "-uitest-hold-beats"]
        app.launch()

        let row = app.buttons["last-time"]
        XCTAssertTrue(row.waitForExistence(timeout: 20), "no last time row to read")
        XCTAssertTrue(row.label.contains("Back Squat"),
                      "the home screen named something other than the heaviest thing she "
                      + "actually lifted: \(row.label)")
        XCTAssertFalse(row.label.contains("Assisted"),
                       "185 lb of counterweight is being read as a 185 lb lift: \(row.label)")
    }
}
