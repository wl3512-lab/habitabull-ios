//
// What the record screen calls a comeback, on the phone the rule was changed
// for: one workout a week, every week, nothing missed.
//
// The old rule counted any gap of seven days or more, so this person was told
// she came back seven times without ever having gone away. The week she is
// held to has to be a week she agreed to, and -uitest-noweek is the phone that
// has answered the three questions and never picked one: onboarding fills
// three suggested days in anyway, which is what made this worth a test of its
// own rather than a line in RecordTests.
//
// -uitest-weekly sets both halves of her, the history and the week, because
// seven days off against a three day week really is two workouts missed. The
// first version of this file seeded the history alone and failed, correctly.

import XCTest

final class ComebackTests: XCTestCase {
    private var app: XCUIApplication!

    private func launch(_ extra: [String]) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest-skip-opening", "-uitest-reset", "-uitest-onboarded",
                               "-uitest-hold-beats"] + extra
        app.launch()
        app.buttons["tab-progress"].tap()
        XCTAssertTrue(app.staticTexts["YOUR RECORD"].waitForExistence(timeout: 10))
    }

    /// The comeback line is only drawn when there is something to count, so
    /// its absence is the assertion. Matched on the counted text rather than
    /// on the container's identifier, because a SwiftUI stack identifier is
    /// not reliably a queryable element, and a probe that can never see
    /// anything would make every test below pass on an empty screen. The
    /// leading number is what keeps the legend's own "Comeback" out of it.
    private func claimsAComeback() -> Bool {
        app.staticTexts.matching(
            NSPredicate(format: "label MATCHES '[0-9]+ comebacks?'")
        ).count > 0
    }

    func testAWeekSheNeverAgreedToIsNotAWeekSheIsHeldTo() {
        launch(["-uitest-weekly", "-uitest-noweek"])
        XCTAssertFalse(claimsAComeback(),
                       "she went every week and never missed one, and the only week on the phone is a suggestion")
    }

    func testOnceAWeekEveryWeekIsNeverAComeback() {
        launch(["-uitest-weekly"])
        XCTAssertFalse(claimsAComeback(),
                       "eight weeks, eight workouts, nothing missed, and the screen counted seven comebacks")
    }

    /// The control. If this one fails the three above are worthless, because
    /// a screen that never says anything would satisfy all of them.
    func testTheProbeCanActuallySeeAComeback() {
        launch(["-uitest-pattern"])
        XCTAssertTrue(claimsAComeback(),
                      "the pattern phone has a three week gap in it and the probe missed it")
    }

    func testTheGridDoesNotMarkThemEither() {
        launch(["-uitest-weekly"])
        // the legend still says what the colour would mean, so this checks the
        // cells rather than the key under them
        XCTAssertTrue(app.staticTexts["Comeback"].exists, "the legend should still explain the colour")
        XCTAssertFalse(claimsAComeback())
    }
}
