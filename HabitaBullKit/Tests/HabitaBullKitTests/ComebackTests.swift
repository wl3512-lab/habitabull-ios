//
// What counts as coming back.
//
// Lucy's rule, November 13 2026: a comeback is two or more workouts she meant
// to do and did not, read against her own week. The thing it replaced counted
// any gap of seven days or more, which made somebody who trains once a week,
// every week, on schedule, a comeback every single time she turned up.
//
// Run in UTC for the same reason the parity tests are: these are local-day
// questions, so the test has to pin which local day it means.

import XCTest
@testable import HabitaBullKit

private let utc = TimeZone(identifier: "UTC")!

/// Days counted back from a fixed Sunday, so the answers never depend on
/// which weekday the suite happens to run on.
private func days(_ back: [Int]) -> [SessionRecord] {
    let cal = Attendance.calendar(utc)
    let anchor = Attendance.date("2026-11-01", cal)!      // a Sunday
    return back.sorted(by: >).map { n in
        let d = cal.date(byAdding: .day, value: -n, to: anchor)!
        return SessionRecord(date: Attendance.day(d, cal), completed: true, loggedSet: true)
    }
}

final class ComebackTests: XCTestCase {

    // MARK: - once a week

    func testOnceAWeekEveryWeekIsNeverAComeback() {
        let weekly = days([28, 21, 14, 7, 0])
        XCTAssertEqual(Attendance.comebackDates(weekly, trainingDays: [1], zone: utc), [],
                       "she never missed one, and the old rule called every week a comeback")
    }

    func testOnceAWeekAndTwoWeeksMissedIsAComeback() {
        // trained, then nothing for three weeks, then back
        let off = days([28, 21, 0])
        XCTAssertEqual(Attendance.comebackDates(off, trainingDays: [1], zone: utc),
                       ["2026-11-01"],
                       "two weeks away and back on the third is the example she gave")
    }

    func testOnceAWeekAndOneWeekMissedIsNot() {
        let off = days([28, 21, 7])
        XCTAssertEqual(Attendance.comebackDates(off, trainingDays: [1], zone: utc), [],
                       "one missed workout is a missed workout, not a comeback")
    }

    // MARK: - three a week, and the rest of the cadences

    func testThreeAWeekMakesAWeekOffAComeback() {
        let plan = [1, 3, 5]
        XCTAssertTrue(Attendance.isComeback(gapDays: 7, trainingDays: plan, missedAtLeast: 2),
                      "three a week is a workout every 2 1/3 days, so seven days is two missed")
        XCTAssertFalse(Attendance.isComeback(gapDays: 6, trainingDays: plan, missedAtLeast: 2))
    }

    func testTwoAWeekNeedsElevenDays() {
        let plan = [1, 4]
        XCTAssertFalse(Attendance.isComeback(gapDays: 10, trainingDays: plan, missedAtLeast: 2))
        XCTAssertTrue(Attendance.isComeback(gapDays: 11, trainingDays: plan, missedAtLeast: 2),
                      "a workout every 3 1/2 days, so two missed is past ten and a half")
    }

    func testTheHarderTheWeekTheSoonerABreakShows() {
        let thresholds = [1: 21, 2: 11, 3: 7, 4: 6, 5: 5, 6: 4, 7: 3]
        for (perWeek, first) in thresholds {
            let plan = Array(0..<perWeek)
            XCTAssertTrue(Attendance.isComeback(gapDays: first, trainingDays: plan, missedAtLeast: 2),
                          "\(perWeek) a week should count \(first) days off")
            XCTAssertFalse(Attendance.isComeback(gapDays: first - 1, trainingDays: plan, missedAtLeast: 2),
                           "\(perWeek) a week should not count \(first - 1) days off")
        }
    }

    // MARK: - the edges

    func testNoWeekAgreedToIsReadAsOnceAWeek() {
        // the gentlest honest assumption, so nobody is told they came back
        // from a break they did not take
        XCTAssertEqual(Attendance.weeklyIntent([]), 1)
        XCTAssertFalse(Attendance.isComeback(gapDays: 20, trainingDays: [], missedAtLeast: 2))
        XCTAssertTrue(Attendance.isComeback(gapDays: 21, trainingDays: [], missedAtLeast: 2))
    }

    func testWhichWeekdaysSheChoseChangesNothing() {
        // only how often, never which days: a three day week is a three day
        // week whether it is Monday, Wednesday, Friday or three in a row
        let spread = days([28, 0])
        XCTAssertEqual(Attendance.comebackDates(spread, trainingDays: [1, 3, 5], zone: utc),
                       Attendance.comebackDates(spread, trainingDays: [0, 1, 2], zone: utc))
    }

    func testARepeatedDayIsNotAGap() {
        let cal = Attendance.calendar(utc)
        let twice = [
            SessionRecord(date: "2026-10-04", completed: true, loggedSet: true),
            SessionRecord(date: "2026-11-01", completed: true, loggedSet: true),
            SessionRecord(date: "2026-11-01", completed: false, loggedSet: true),
        ]
        XCTAssertEqual(Attendance.comebackDates(twice, trainingDays: [1], zone: utc), ["2026-11-01"])
        XCTAssertNotNil(Attendance.date("2026-11-01", cal))
    }

    func testASessionSheLoggedNothingInIsNotATurningUp() {
        let empty = [
            SessionRecord(date: "2026-10-04", completed: true, loggedSet: true),
            SessionRecord(date: "2026-10-18", completed: false, loggedSet: false),
            SessionRecord(date: "2026-11-01", completed: true, loggedSet: true),
        ]
        XCTAssertEqual(Attendance.comebackDates(empty, trainingDays: [1], zone: utc),
                       ["2026-11-01"],
                       "opening the app in the middle of a break does not break the break")
    }

    func testOneSessionEverCannotBeAComeback() {
        XCTAssertEqual(Attendance.comebackDates(days([0]), trainingDays: [1], zone: utc), [])
        XCTAssertEqual(Attendance.comebackDates([], trainingDays: [1], zone: utc), [])
        XCTAssertEqual(Attendance.longestComebackGap(days([0]), trainingDays: [1], zone: utc), 0)
    }

    // MARK: - the longest break she came back from

    func testTheLongestGapOnlyCountsBreaksSheCameBackFrom() {
        let off = days([60, 53, 11, 4])
        XCTAssertEqual(Attendance.longestComebackGap(off, trainingDays: [1], zone: utc), 42,
                       "the six week break, not the week she took after it")
    }

    func testTheLongestGapIsZeroWhenNothingCounted() {
        XCTAssertEqual(Attendance.longestComebackGap(days([21, 14, 7, 0]), trainingDays: [1], zone: utc), 0)
    }

    // MARK: - the grid says the same thing the count does

    func testTheMonthGridMarksTheSameDays() {
        let off = days([28, 21, 0])
        let grid = Attendance.monthMatrix(year: 2026, month: 11, sessions: off, trainingDays: [1],
                                          today: "2026-11-01", zone: utc)
        let marked = grid.flatMap { $0 }.filter(\.comeback).compactMap(\.date)
        XCTAssertEqual(marked, ["2026-11-01"])
    }
}
