//
// the shape of a week.

import XCTest
@testable import HabitaBullKit

final class SplitTests: XCTestCase {
    func testOneDayAWeekIsAWholeBody() {
        // a single push day is a week with no legs in it
        XCTAssertEqual(Split.labels(1), ["Full body"])
    }

    func testThreeDaysIsPushPullLegs() {
        XCTAssertEqual(Split.labels(3), ["Push day", "Pull day", "Leg day"])
    }

    func testEveryWeekGetsAsManyNamesAsItHasDays() {
        for count in 1...7 {
            XCTAssertEqual(Split.labels(count).count, count,
                           "a week of \(count) days was handed the wrong number of names")
        }
    }

    func testNoWeekAtAllIsNoNames() {
        XCTAssertEqual(Split.labels(0), [])
        XCTAssertEqual(Split.labels(-2), [])
    }

    func testAWeekLongerThanSevenDaysStillAnswers() {
        // the week picker cannot ask for more than seven, but a saved profile
        // from another version could, and a crash here would be on launch
        XCTAssertFalse(Split.labels(9).isEmpty)
    }

    func testNoDayIsNamedTwiceInARowWithinASplit() {
        for count in 1...7 {
            let names = Split.labels(count)
            for (one, next) in zip(names, names.dropFirst()) {
                XCTAssertNotEqual(one, next,
                                  "a \(count) day week trains the same thing twice running")
            }
        }
    }

    func testEveryNameItHandsOutIsOneItKnows() {
        for count in 1...7 {
            for name in Split.labels(count) {
                XCTAssertTrue(Split.known.contains(name), "\(name) is not in the known list")
            }
        }
    }
}
