//
// does the bar actually cover what is behind it.
//
// The accessibility tree cannot answer this. It reports where an element is
// laid out, not whether anything is drawn on top of it, and a scroll view's
// content legitimately continues under a bar. The only thing that can tell
// you whether the bar is opaque is the picture, so this one reads pixels.
//
// Found on the record screen on 2026-11-17: at rest, with the month grid at
// the top, the words "1 comeback" were printed in cyan across the bottom of
// the bar, under the tab labels. The bar's fill was pinned to 52pt and so
// stopped at the top of the home indicator's strip, and the page showed
// through the rest.

import XCTest

final class TabBarCoverTests: XCTestCase {
    /// The app background, 0x16181D, as the simulator renders it.
    private let ground = (r: 0x16, g: 0x18, b: 0x1D)

    /// Every tab bar strip in the app is the same strip, so one screen with
    /// something bright right under the fold is enough to prove it opaque.
    /// The record screen is that screen: the comeback line is cyan and sits
    /// at the very bottom of a page taller than the phone.
    func testNothingShowsThroughTheBottomOfTheBar() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-skip-opening", "-uitest-reset", "-uitest-onboarded",
                               "-uitest-hold-beats", "-loadTheBar", "NO", "-uitest-pattern",
                               // said out loud, or the colours read here mean
                               // whatever text size the machine was last on
                               "-UIPreferredContentSizeCategoryName",
                               "UICTContentSizeCategoryLarge"]
        app.launch()
        app.goTo("progress")
        XCTAssertTrue(app.staticTexts["YOUR RECORD"].waitForExistence(timeout: 20),
                      "the record screen never opened")
        // let the page settle. this defect survived three seconds, so a
        // screenshot taken during the tab change would have found it too,
        // but a settled one cannot be argued with
        Thread.sleep(forTimeInterval: 2)

        let shot = XCUIScreen.main.screenshot()
        let keep = XCTAttachment(screenshot: shot)
        keep.name = "100-the-bottom-of-the-bar"
        keep.lifetime = .keepAlways
        add(keep)

        guard let image = UIImage(data: shot.pngRepresentation).flatMap({ $0.cgImage }) else {
            return XCTFail("no picture to read")
        }
        let tab = app.buttons["tab-today"]
        let window = app.windows.firstMatch.frame
        let scale = CGFloat(image.width) / window.width

        // from just under the labels to the bottom edge. the home indicator
        // is a pale pill in the middle of this strip and is drawn by the
        // system, not by us, so only the left third is read.
        let top = Int((tab.frame.maxY + 2) * scale)
        let bottom = image.height - 1
        let left = 0
        let right = Int(window.width * scale / 3)
        guard bottom - top > 10 else {
            // a phone with no home indicator has no strip under the bar for
            // anything to show through. That is not a pass and not a
            // failure, it is a different shape of phone, and calling it
            // either would be a lie about what was checked.
            XCTAssertGreaterThanOrEqual(tab.frame.maxY, window.maxY - 2,
                                        "there is no strip under the labels, and the bar does "
                                        + "not reach the bottom of the screen either")
            return
        }

        var worst = (0, 0, 0)
        var worstAt = (0, 0)
        var offByMoreThanEight = 0
        var read = 0
        guard let data = image.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            return XCTFail("could not read the picture's pixels")
        }
        let perRow = image.bytesPerRow
        let perPixel = image.bitsPerPixel / 8
        func pixel(_ x: Int, _ y: Int) -> (Int, Int, Int) {
            let at = y * perRow + x * perPixel
            return (Int(bytes[at]), Int(bytes[at + 1]), Int(bytes[at + 2]))
        }
        for y in stride(from: top, through: bottom, by: 2) {
            for x in stride(from: left, to: right, by: 2) {
                let (r, g, b) = pixel(x, y)
                read += 1
                let off = max(abs(r - ground.r), abs(g - ground.g), abs(b - ground.b))
                if off > 8 { offByMoreThanEight += 1 }
                if off > max(abs(worst.0 - ground.r), abs(worst.1 - ground.g),
                             abs(worst.2 - ground.b)) {
                    worst = (r, g, b)
                    worstAt = (x, y)
                }
            }
        }
        XCTAssertGreaterThan(read, 100, "the strip under the labels was never read")

        // The positive control, and this test is worth very little without
        // it. A strip that is all background proves the bar is opaque only
        // if there was something behind it to hide. If the page ever got
        // shorter, or the grid moved, this would pass on an empty screen and
        // call it covered. So: check that the band just above the bar, where
        // the page is deliberately left showing through, is NOT all
        // background. If something is visible there, something was behind
        // the bar too.
        var showsThrough = 0
        let bandTop = Int((tab.frame.minY - 40) * scale)
        let bandBottom = Int((tab.frame.minY - 4) * scale)
        for y in stride(from: max(0, bandTop), to: max(1, bandBottom), by: 2) {
            for x in stride(from: left, to: right, by: 2) {
                let p = pixel(x, y)
                if max(abs(p.0 - ground.r), abs(p.1 - ground.g), abs(p.2 - ground.b)) > 8 {
                    showsThrough += 1
                }
            }
        }
        XCTAssertGreaterThan(showsThrough, 0,
                             "nothing is visible in the band above the bar, so there was "
                             + "nothing behind the bar either and a clean strip under it "
                             + "proves nothing")

        // and the stronger half of the same argument. Ink above the bar says
        // what is beside it, not what is under it; a page that stopped
        // exactly at the top of the bar would satisfy the band and still
        // leave the strip below clean for the wrong reason.
        //
        // So ask the hierarchy for something behind the bar itself, over the
        // same columns these pixels came from. The bar's fill is one shape:
        // ink anywhere under it is ink it has to hide, and the strip below
        // the labels is only where the system draws nothing of its own to
        // confuse the reading. Found by a codex audit 2026-11-17.
        // and it has to be the same strip, not the whole bar. One shape can
        // cover the top of the bar and leave the bottom of it showing, which
        // is exactly the defect this test was written for, so a control that
        // accepted content anywhere under the bar's top accepted content in
        // the half that was never in question. These are the pixels read
        // above, in points. Found by a codex audit 2026-11-17.
        let sampled = CGRect(x: CGFloat(left) / scale,
                             y: CGFloat(top) / scale,
                             width: CGFloat(right - left) / scale,
                             height: CGFloat(bottom - top) / scale)
        // the page, not the bar: the tab labels are static text too, and they
        // are drawn by the thing being tested.
        let page = app.scrollViews.firstMatch
        XCTAssertTrue(page.exists, "the record screen has no scrolling page to look behind")
        let behind = page.staticTexts.allElementsBoundByIndex.filter {
            let frame = $0.frame
            return frame.height > 1 && frame.width > 1 && frame.intersects(sampled)
        }
        XCTAssertFalse(behind.isEmpty,
                       "no page content is behind \(sampled), the strip these pixels came "
                       + "from, so a clean reading says only that the page ends above it")
        XCTAssertEqual(offByMoreThanEight, 0,
                       "\(offByMoreThanEight) of \(read) pixels under the tab labels are not "
                       + "the app's background. The worst is "
                       + String(format: "#%02X%02X%02X", worst.0, worst.1, worst.2)
                       + " at \(worstAt). Something is showing through the bar.")
    }
}
