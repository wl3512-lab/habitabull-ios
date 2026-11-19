//
// how big the things you tap actually are, and whether the whole of them works.
//
// The large-text tests measured these too, but only reported them, because at
// the largest sizes everything grows and the number means less. These are at
// the ordinary text size, where a control under 44pt is under 44pt for
// everyone.
//
// 44 is Apple's figure and it is not arbitrary: it is roughly the width of a
// fingertip. A 20pt-tall button is one a thumb misses, and missing a control
// in a calendar means opening the wrong day.
//
// Every one of these taps the outermost edge of the target as well as
// measuring it. A frame can be made 44pt by padding while the part that
// answers a tap stays small, and then the measurement says the fix landed
// when it did not.

import XCTest

final class TapTargetTests: XCTestCase {
    private var app: XCUIApplication!

    /// Said out loud rather than left to the simulator's settings. Without it
    /// these numbers mean whatever text size the machine was last left on,
    /// and the whole point of this file is the ordinary one.
    private let ordinary = ["-UIPreferredContentSizeCategoryName",
                            "UICTContentSizeCategoryLarge"]

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest-skip-opening", "-uitest-reset", "-uitest-onboarded",
                               "-uitest-hold-beats", "-loadTheBar", "NO"] + ordinary
    }

    private func still(_ named: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = named
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Asserts, rather than reports. Both sides: a control can be wide and
    /// flat, which is the shape every one of these defects took.
    private func bigEnough(_ element: XCUIElement, _ what: String,
                           file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 10),
                      "\(what) is not on the screen", file: file, line: line)
        let f = element.frame
        XCTAssertGreaterThanOrEqual(f.height, 44,
            "\(what) is \(Int(f.width))x\(Int(f.height))pt. 44 tall is the smallest a thumb finds",
            file: file, line: line)
        XCTAssertGreaterThanOrEqual(f.width, 44,
            "\(what) is \(Int(f.width))x\(Int(f.height))pt. 44 wide is the smallest a thumb finds",
            file: file, line: line)
    }

    /// The month the grid opens on is this month, and the seeded history runs
    /// from four to seventy days back. In the first week of a month that puts
    /// every trained day in the month before, and a test that looked only at
    /// the month on screen would fail on the 1st for no reason anybody could
    /// find on the 17th. So page back until there is a day to look at.
    private func aTrainedDay() -> XCUIElement {
        let trained = NSPredicate(format: "label CONTAINS ', trained' OR label CONTAINS ', came back'")
        var steps = 0
        while app.buttons.matching(trained).count == 0 && steps < 4 {
            app.buttons["month-back"].tap()
            steps += 1
        }
        return app.buttons.matching(trained).firstMatch
    }

    /// A day in the month grid opens that day. The coloured tile is 34pt and
    /// the tap area was the tile.
    func testADayInTheCalendarIsBigEnoughToTap() {
        app.launchArguments += ["-uitest-pattern"]
        app.launch()
        app.goTo("progress")
        XCTAssertTrue(app.staticTexts["YOUR RECORD"].waitForExistence(timeout: 20),
                      "the record screen never opened")
        let day = aTrainedDay()
        still("99-a-calendar-day")
        bigEnough(day, "a trained day in the calendar")

        // and the padding answers, not just the tile. 8% down a 44pt target
        // is 3.5pt in, which is inside the 5pt that was added and outside the
        // 34pt that was always there.
        // which day it is, read before the tap, because after it the grid is
        // gone. The identifier is "day-2026-11-05".
        let wanted = day.identifier
        day.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        XCTAssertTrue(app.otherElements["day-detail"].waitForExistence(timeout: 10)
                      || app.descendants(matching: .any)["day-detail"].waitForExistence(timeout: 2),
                      "the top of a calendar day measures 44pt and does not answer a tap, "
                      + "so the padding is decoration")

        // and it is the day she tapped. The tiles sit on a 44pt pitch with
        // 34pt of colour, so a tap 8% down one of them is near the day above
        // it, and "a day screen opened" is exactly what a tap landing on the
        // wrong day would also report. Found by a codex audit 2026-11-17.
        let shown = app.staticTexts["day-detail-date"]
        XCTAssertTrue(shown.waitForExistence(timeout: 10), "the day screen has no date on it")
        let iso = String(wanted.dropFirst("day-".count))
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        XCTAssertEqual(parts.count, 3, "could not read a date out of \(wanted)")
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = .current
        let when = gregorian.date(from: DateComponents(year: parts[0], month: parts[1],
                                                       day: parts[2]))
        XCTAssertEqual(shown.label,
                       when?.formatted(.dateTime.weekday(.wide).month().day()),
                       "the tap near the top of \(iso) opened a different day")
    }

    /// Strip takes every plate off at once. It was a bare word in a row: 37
    /// wide and 20 tall, the smallest target in the app.
    func testStripIsBigEnoughToTap() {
        app.launchArguments = ["-uitest-skip-opening", "-uitest-reset", "-uitest-onboarded",
                               "-uitest-hold-beats", "-loadTheBar", "YES"] + ordinary
        app.launch()
        let begin = app.buttons["Start workout"]
        XCTAssertTrue(begin.waitForExistence(timeout: 30), "Today never appeared")
        begin.tap()
        let plate = app.buttons["Add one 45 pound plate to each side"]
        XCTAssertTrue(plate.waitForExistence(timeout: 10), "the plate view never opened")
        // Strip is disabled with an empty bar, and a disabled control is not
        // a tap target. Load one plate so the real one is on screen.
        plate.tap()
        // the heading is drawn uppercased, and XCUITest reports what was
        // drawn. Asking for "Empty bar" matched nothing and made a working
        // Strip look broken.
        XCTAssertTrue(app.staticTexts["45 A SIDE"].waitForExistence(timeout: 5),
                      "the plate never went on, so there is nothing to strip")
        still("99b-the-plate-controls")
        bigEnough(app.buttons["Strip"], "Strip")
        bigEnough(app.buttons["Remove last plate"], "Undo")

        // the corner of the target, well outside the word itself. 8% and 12%
        // of 44pt is 3.5pt in and 5pt down, which is inside the frame that
        // was added and outside the 37x20 word that was always there.
        app.buttons["Strip"].coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.12)).tap()
        XCTAssertTrue(app.staticTexts["EMPTY BAR"].waitForExistence(timeout: 5),
                      "Strip measures 44pt and only the word in the middle of it answers a tap")
    }
}
