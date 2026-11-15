//
// reading a typed number. the phone writes the number one way and the person
// types it back the same way, and the app has to agree with both. found by a
// codex review on 2026-11-15: a weight typed as 22,5 in germany was rejected
// and the old number kept, with nothing on screen to say so.

import XCTest
@testable import HabitaBull

final class NumberFieldTests: XCTestCase {
    private let us = Locale(identifier: "en_US")
    private let de = Locale(identifier: "de_DE")

    func testADecimalCommaIsAWeight() {
        XCTAssertEqual(NumberStepper.number(from: "22,5", locale: de), 22.5)
    }

    func testADecimalPointIsStillAWeight() {
        XCTAssertEqual(NumberStepper.number(from: "22.5", locale: us), 22.5)
    }

    // the field opens on value.formatted(), which groups above a thousand.
    // reading those back with plain Double gives 1 in germany and nil here
    func testTheGroupedNumberTheFieldItselfWroteReadsBack() {
        XCTAssertEqual(NumberStepper.number(from: "1,000", locale: us), 1000)
        XCTAssertEqual(NumberStepper.number(from: "1.000", locale: de), 1000)
    }

    func testHalfTypedInputIsStillRead() {
        XCTAssertEqual(NumberStepper.number(from: "22.", locale: us), 22)
        XCTAssertEqual(NumberStepper.number(from: "135", locale: de), 135)
    }

    // nothing typed is not a weight of zero: the old number has to stand
    func testNothingIsNotANumber() {
        XCTAssertNil(NumberStepper.number(from: "", locale: us))
        XCTAssertNil(NumberStepper.number(from: "lb", locale: us))
    }
}
