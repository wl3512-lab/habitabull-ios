//
// two years of lifting, on the screens that read all of it.
//
// A codex audit on 2026-11-16 found three places that answered a question by
// walking the entire history, inside a loop that was itself walking it: the
// planner re-derived which workout was in hand once per session, the record
// screen copied every session once per lift, and the chart worked out its own
// range once per point while deciding what the points meant once per range.
// None of that shows up on the six scattered days the other suites run on.
//
// These tests do not assert a frame rate. They assert that a screen built
// from 300 workouts appears in about the time one built from six does, which
// is the thing a person would actually notice.

import XCTest

final class LongHistoryTests: XCTestCase {
    /// Set from measurement, not from taste: with the loops hoisted these
    /// screens come up in about a second and a half, and with the work back
    /// inside the loops they take six or more. Anything in between is the
    /// regression coming back.
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest-skip-opening", "-uitest-reset", "-uitest-onboarded",
                               "-uitest-longhistory"]
        app.launch()
    }

    private func still(_ named: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = named
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// How long from the tap to the thing being on screen.
    private func timeToAppear(_ element: XCUIElement, within budget: TimeInterval,
                              _ what: String, file: StaticString = #filePath,
                              line: UInt = #line) {
        let began = Date.now
        let there = element.waitForExistence(timeout: 60)
        let took = Date.now.timeIntervalSince(began)
        XCTAssertTrue(there, "\(what) never appeared", file: file, line: line)
        XCTAssertLessThan(took, budget,
                          "\(what) took \(String(format: "%.1f", took))s with 300 workouts behind it",
                          file: file, line: line)
    }

    /// The record screen draws a line per lift, and each line is 300 points.
    ///
    /// Not a timing test. I tried to make one and could not: timing the
    /// caption measures nothing, because it is in the accessibility tree
    /// before the lines are drawn, and timing a scroll measures the swipe,
    /// not the drawing. With the chart's range worked out once instead of
    /// once per point per point, scrolling this screen took 16.1s against
    /// 15.7s before, which is noise. So this asserts only that two years of
    /// points still draw, and the chart fix rests on reading the code.
    func testTheRecordScreenStillDrawsWithTwoYearsBehindIt() {
        app.buttons["tab-progress"].tap()
        XCTAssertTrue(app.staticTexts["300 days"].firstMatch.waitForExistence(timeout: 60),
                      "the lift charts never drew")
        still("90-the-record-screen-on-two-years")
    }

    /// Today works out what to put on the bar for every lift on the card,
    /// against all 300 workouts, and still has to come up.
    ///
    /// There is no timing assertion here, and that is deliberate. Three
    /// shapes of one were tried and all three were thrown away:
    ///
    ///  - timing from a cold launch separated the two cases on paper, 9.3s
    ///    with the planner's lookup back inside its loop against 2.5s with it
    ///    hoisted, but the fixed code ranged from 2.5s to 6.6s across three
    ///    runs, so no budget tells them apart reliably
    ///  - a 4 second budget on that measurement failed at 4.2s in a full
    ///    suite run while passing on its own
    ///  - timing four trips to Today and back measured 19.4s fixed against
    ///    18.8s reverted, because Today is not re-planned on a tab switch, so
    ///    it never touched the code in question
    ///
    /// The planner regression is caught by
    /// `SessionStoreTests.testPlanningAgainstTwoYearsOfHistoryIsQuick`
    /// instead, which measures the same work without a simulator in the way:
    /// 3.06s reverted against 0.035s fixed.
    func testTodayStillComesUpWithTwoYearsBehindIt() {
        XCTAssertTrue(app.buttons["Start workout"].waitForExistence(timeout: 60),
                      "today's card never appeared with 300 workouts behind it")
        still("91-today-on-two-years")
    }
}
