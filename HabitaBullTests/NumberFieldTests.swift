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
    /// Rounding corrects the field. The limits wait until she is done.
    ///
    /// Every keystroke is read, so "1" on its way to "15" is a whole number
    /// in its own right, and a field with a minimum of 2.5 put 2.5 back under
    /// her fingers. Deleting that gave "2." and 2.5 again: the goal weight
    /// could not be cleared and no number starting below the minimum could be
    /// typed at all. Found by a codex audit 2026-11-18.
    func testANumberOnItsWayIsLeftAlone() {
        let onTheWay = NumberStepper.accepted("1", minimum: 2.5, maximum: 999, halves: true)
        XCTAssertEqual(onTheWay?.value, 2.5, "the value she would save has to stay loadable")
        XCTAssertNil(onTheWay?.draft,
                     "the field was rewritten while she was still typing, so backspace "
                     + "could never clear it")

        XCTAssertNil(NumberStepper.accepted("2.", minimum: 2.5, maximum: 999, halves: true)?.draft)

        // and rounding still corrects it, which is the other half of the rule
        let rounded = NumberStepper.accepted("22.3", minimum: 0, maximum: 999, halves: true)
        XCTAssertEqual(rounded?.value, 22.5)
        XCTAssertEqual(rounded?.draft, "22.5",
                       "the field is showing a weight the app will not save")

        // reps are whole, so a half is a correction too
        let reps = NumberStepper.accepted("8.5", minimum: 1, maximum: 50, halves: false)
        XCTAssertEqual(reps?.value, 9)
        XCTAssertEqual(reps?.draft, "9")
    }

    func testNothingIsNotANumber() {
        XCTAssertNil(NumberStepper.number(from: "", locale: us))
        XCTAssertNil(NumberStepper.number(from: "lb", locale: us))
    }
}
