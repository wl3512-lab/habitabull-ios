//
// Turning up, as the calendar, the strip, the streak and the month count all
// read it, against the web's answers.
//
// The fixture is generated with TZ=UTC and these tests run in UTC for the same
// reason: every one of these functions is local-time by design, so the two
// sides have to agree on which local day it is before they can agree on
// anything else. The app runs in the phone's zone; this pins the comparison.

import XCTest
@testable import HabitaBullKit

private let utc = TimeZone(identifier: "UTC")!

private struct Case: Decodable {
    let rows: [[J]]
    let attended: [Bool]
    let perToday: [PerToday]
    let comebacks: [String]
    let longest: Int
    let months: [Month]
    let year: [Int]

    struct PerToday: Decodable {
        let today: String
        let checkins: [String]
        let strip: [[J]]
        let streak: Int
    }
    struct Month: Decodable {
        let y: Int, m: Int
        let grid: [[[J]]]
        let count: Int
    }
}

private enum J: Decodable {
    case s(String), n(Double), b(Bool), null
    init(from d: Decoder) throws {
        let c = try d.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(String.self) { self = .s(v) }
        else if let v = try? c.decode(Bool.self) { self = .b(v) }
        else { self = .n(try c.decode(Double.self)) }
    }
    var text: String? { if case .s(let v) = self { return v }; return nil }
    var str: String { text ?? "" }
    var int: Int { if case .n(let v) = self { return Int(v) }; return 0 }
    var intOrNil: Int? { if case .n(let v) = self { return Int(v) }; return nil }
    var flag: Bool { if case .b(let v) = self { return v }; return false }
}

final class AttendanceParityTests: XCTestCase {
    private func load() throws -> [Case] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "attendance", withExtension: "json"))
        return try JSONDecoder().decode([Case].self, from: Data(contentsOf: url))
    }

    private func records(_ rows: [[J]]) -> [SessionRecord] {
        rows.map { SessionRecord(date: $0[0].str, completed: $0[1].flag, loggedSet: $0[2].flag) }
    }

    func testALoggedSetIsProofSheTurnedUp() throws {
        for c in try load() {
            let got = records(c.rows).map(\.attended)
            XCTAssertEqual(got, c.attended, "\(c.rows.map { $0[0].str })")
        }
    }

    func testTheWeekStripAndTheStreakAndTheCheckins() throws {
        for c in try load() {
            let sessions = records(c.rows)
            for day in c.perToday {
                // sorted on both sides, because the fixture was written sorted
                XCTAssertEqual(Attendance.checkinDates(sessions, today: day.today).sorted(), day.checkins,
                               "check-ins on \(day.today)")
                // and once unsorted, so the order it hands them back is pinned too
                XCTAssertEqual(Attendance.checkinDates(sessions, today: day.today),
                               sessions.filter { $0.completed || ($0.date < day.today && $0.attended) }
                                   .map(\.date).reduce(into: [String]()) { out, d in
                                       if !out.contains(d) { out.append(d) }
                                   },
                               "check-in order on \(day.today)")
                XCTAssertEqual(Attendance.streakWeeks(sessions, today: day.today, zone: utc), day.streak,
                               "streak on \(day.today)")
                let strip = Attendance.weekStrip(sessions, trainingDays: [1, 3, 5], today: day.today, zone: utc)
                XCTAssertEqual(strip.count, day.strip.count)
                for (mine, row) in zip(strip, day.strip) {
                    XCTAssertEqual(mine.index, row[0].int, "strip index on \(day.today)")
                    XCTAssertEqual(mine.initial, row[1].str, "strip letter on \(day.today)")
                    XCTAssertEqual(mine.date, row[2].str, "strip date on \(day.today)")
                    XCTAssertEqual(mine.trained, row[3].flag, "\(mine.date) trained")
                    XCTAssertEqual(mine.isToday, row[4].flag, "\(mine.date) today")
                    XCTAssertEqual(mine.planned, row[5].flag, "\(mine.date) planned")
                    XCTAssertEqual(mine.upcoming, row[6].flag, "\(mine.date) upcoming")
                }
            }
        }
    }

    /// The web counts any gap of seven days or more. The app counts two
    /// missed workouts or more, read against the week she agreed to, so the
    /// two only line up at three days a week: three a week is a workout every
    /// 2 1/3 days, and two of those missed is seven days. That is the week the
    /// fixture is checked at, deliberately, because it is the one cadence
    /// where the port is still provably faithful. Away from it the app is
    /// meant to differ, and ComebackTests is where that is pinned.
    func testComebacksAndTheLongestGap() throws {
        for c in try load() {
            let sessions = records(c.rows)
            XCTAssertEqual(Attendance.comebackDates(sessions, trainingDays: [1, 3, 5], zone: utc).sorted(),
                           c.comebacks)
            XCTAssertEqual(Attendance.longestComebackGap(sessions, trainingDays: [1, 3, 5], zone: utc),
                           c.longest)
        }
    }

    func testTheMonthGridCellForCell() throws {
        for c in try load() {
            let sessions = records(c.rows)
            for month in c.months {
                // the web's month is 0-indexed, this one is 1-12
                // three days a week, for the reason in testComebacksAndTheLongestGap
                let grid = Attendance.monthMatrix(year: month.y, month: month.m + 1, sessions: sessions,
                                                  trainingDays: [1, 3, 5],
                                                  photoDates: ["2026-11-03"], today: "2026-11-06", zone: utc)
                XCTAssertEqual(grid.count, month.grid.count, "rows in \(month.y)-\(month.m + 1)")
                for (row, want) in zip(grid, month.grid) {
                    XCTAssertEqual(row.count, want.count)
                    for (cell, e) in zip(row, want) {
                        let at = "\(month.y)-\(month.m + 1) cell \(e[1].intOrNil.map(String.init) ?? "pad")"
                        XCTAssertEqual(cell.date, e[0].text, at)
                        XCTAssertEqual(cell.day, e[1].intOrNil, at)
                        XCTAssertEqual(cell.trained, e[2].flag, "\(at) trained")
                        XCTAssertEqual(cell.comeback, e[3].flag, "\(at) comeback")
                        XCTAssertEqual(cell.isToday, e[4].flag, "\(at) today")
                        XCTAssertEqual(cell.future, e[5].flag, "\(at) future")
                        XCTAssertEqual(cell.hasPhoto, e[6].flag, "\(at) photo")
                    }
                }
                XCTAssertEqual(Attendance.sessionsInMonth(sessions, year: month.y, month: month.m + 1), month.count,
                               "count for \(month.y)-\(month.m + 1)")
            }
            XCTAssertEqual(Attendance.yearCounts(sessions, year: 2026), c.year)
        }
    }
}
