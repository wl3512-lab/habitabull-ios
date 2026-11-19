//
// One way to go to a place, because the obvious way is a race.
//

import XCTest
import UIKit

extension XCTestCase {
    /// How much of the chart's own colour is drawn inside a rect on screen.
    ///
    /// Every label on a lift card survives deleting the area and the stroke,
    /// which leaves a card with one dot in it and nothing to read: the
    /// numbers were all still right and the chart was gone. The line is the
    /// only cyan in the card, so this counts it.
    ///
    /// Compared as a sorted triple so the channel order of the screenshot
    /// does not matter, and so that grey never counts: the brand cyan is
    /// #8EB4BD, whose three channels are 47 apart.
    func cyanPixels(in rect: CGRect, of app: XCUIApplication) -> Int {
        let shot = XCUIScreen.main.screenshot()
        guard let image = UIImage(data: shot.pngRepresentation)?.cgImage,
              let data = image.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return 0 }
        let wide = app.windows.firstMatch.frame.width
        guard wide > 0 else { return 0 }
        let scale = CGFloat(image.width) / wide
        let perRow = image.bytesPerRow
        let perPixel = image.bitsPerPixel / 8
        let x0 = max(0, Int(rect.minX * scale)), x1 = min(image.width, Int(rect.maxX * scale))
        let y0 = max(0, Int(rect.minY * scale)), y1 = min(image.height, Int(rect.maxY * scale))
        guard x1 > x0, y1 > y0 else { return 0 }
        let want = [142, 180, 189]
        var count = 0
        for y in y0..<y1 {
            for x in x0..<x1 {
                let at = y * perRow + x * perPixel
                let got = [Int(bytes[at]), Int(bytes[at + 1]), Int(bytes[at + 2])].sorted()
                if zip(got, want).allSatisfy({ abs($0 - $1) < 24 }) { count += 1 }
            }
        }
        return count
    }
}

extension XCUIApplication {
    /// Tap one of the three tabs, once the bar is really there.
    ///
    /// `app.buttons["tab-progress"].tap()` straight after a launch looks safe
    /// and is not. XCUITest finds the button as soon as it is in the
    /// accessibility tree, which happens before SwiftUI has given it a frame,
    /// and a tap on a frameless element goes to hit point {-1, -1}: it is
    /// reported as a tap, nothing is tapped, and the test fails some lines
    /// later on whatever was supposed to appear.
    ///
    /// That is what happened to ComebackTests.testADaySheCameBackOnSaysSoOutLoud
    /// in the full run on 2026-11-17. The log reads "Computed hit point
    /// {-1, -1} after scrolling to visible", then ten seconds of waiting for
    /// "YOUR RECORD", then a failed assertion about comeback days, which had
    /// nothing to do with comeback days. The suite was red for a reason that
    /// was not in the app.
    ///
    /// It bites on the first launch of a run, where the app is cold and the
    /// machine is still busy from the build: that launch took 1.71s to set up
    /// its automation session against 1.29s for every launch after it. So it
    /// lands on whichever UI class happens to run first, and it cannot be
    /// reproduced to order. Uninstalling the app and running the same class
    /// alone put the setup back at 0.99s and passed five times out of five.
    /// Which is why this is a wait and not a fix to a line of app code: there
    /// is nothing wrong with the tab bar, only with asking it a question
    /// before it has been drawn.
    ///
    /// Waiting on the frame, not on `isHittable`. `isHittable` is true for a
    /// control hanging off the bottom of the screen, which LargeTextTests had
    /// to learn the hard way, and it was true here too.
    func goTo(_ place: String, file: StaticString = #filePath, line: UInt = #line) {
        let tab = buttons["tab-\(place)"]
        XCTAssertTrue(tab.waitForExistence(timeout: 30),
                      "the tab bar never appeared, so there was no \(place) tab to tap",
                      file: file, line: line)

        // and then until it has somewhere to be tapped. Polling, because there
        // is no expectation for "has a frame": frame is read off the last
        // snapshot and does not publish changes.
        let deadline = Date().addingTimeInterval(10)
        while tab.frame.width < 1 || tab.frame.height < 1, Date() < deadline {
            usleep(100_000)
        }
        // both, because the wait above is on both and asserting only the
        // width let a tab 127pt wide and 0pt tall through the check and on to
        // a tap at its middle, which is the bug this helper exists to stop.
        XCTAssertGreaterThan(Swift.min(tab.frame.width, tab.frame.height), 1,
                             "the \(place) tab is in the accessibility tree with no frame after "
                             + "10s, so a tap on it would be sent nowhere and every assertion "
                             + "after it would be about the wrong thing",
                             file: file, line: line)
        tab.tap()
    }
}
