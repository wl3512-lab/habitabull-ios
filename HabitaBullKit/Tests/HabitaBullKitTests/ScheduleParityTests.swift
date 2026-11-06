//
// The scheduling rules and the sentence parser, against the web's answers.
//
// Fixtures/schedule.json holds what lib/schedule.ts replies to 47 real
// phrasings ("free most evenings but wednesdays are bad", "can't do mondays",
// "3x a week"), every day placement, every spread, every hour of the day and
// a set of anchor combinations. The parser is the part that earns this: it is
// the offline fallback and the checker the model's answer has to pass, so a
// Swift regex that is a shade looser than the JavaScript one would quietly
// accept plans the web version rejected.

import XCTest
@testable import HabitaBullKit

private struct Fixture: Decodable {
    let parses: [[J]], places: [[J]], spreads: [[J]], backToBack: [[J]]
    let hours: [[J]], anchors: [[J]], nexts: [[J]], observed: [[J]]
}

private enum J: Decodable {
    case s(String), n(Double), b(Bool), a([J]), null
    init(from d: Decoder) throws {
        let c = try d.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(String.self) { self = .s(v) }
        else if let v = try? c.decode(Bool.self) { self = .b(v) }
        else if let v = try? c.decode(Double.self) { self = .n(v) }
        else { self = .a(try c.decode([J].self)) }
    }
    var text: String? { if case .s(let v) = self { return v }; return nil }
    var str: String { text ?? "" }
    var int: Int { if case .n(let v) = self { return Int(v) }; return 0 }
    var flag: Bool { if case .b(let v) = self { return v }; return false }
    var ints: [Int] { if case .a(let v) = self { return v.map(\.int) }; return [] }
    var list: [J] { if case .a(let v) = self { return v }; return [] }
    var isNull: Bool { if case .null = self { return true }; return false }
}

final class ScheduleParityTests: XCTestCase {
    private func load() throws -> Fixture {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "schedule", withExtension: "json"))
        return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }

    func testTheParserReadsEveryPhraseTheSameWay() throws {
        let f = try load()
        XCTAssertGreaterThan(f.parses.count, 40)
        for row in f.parses {
            let text = row[0].str
            let got = Schedule.parseAvailability(text)
            XCTAssertEqual(got.days, row[1].ints, "days of \"\(text)\"")
            XCTAssertEqual(got.avoid, row[2].ints, "avoid of \"\(text)\"")
            XCTAssertEqual(got.anchor?.rawValue, row[3].text, "anchor of \"\(text)\"")
            XCTAssertEqual(got.count, row[4].isNull ? nil : row[4].int, "count of \"\(text)\"")
            // and the week each one actually produces, at three frequencies
            XCTAssertEqual(Schedule.planWeek(got), row[5].ints, "week of \"\(text)\"")
            XCTAssertEqual(Schedule.planWeek(got, fallbackCount: 2), row[6].ints, "2-day week of \"\(text)\"")
            XCTAssertEqual(Schedule.planWeek(got, fallbackCount: 4), row[7].ints, "4-day week of \"\(text)\"")
        }
    }

    func testDayPlacementMatchesForEveryCountAndStartingDay() throws {
        for row in try load().places {
            let today = row[1].isNull ? nil : row[1].int
            XCTAssertEqual(Schedule.placeDays(row[0].int, today: today), row[2].ints,
                           "\(row[0].int) days starting \(today.map(String.init) ?? "anywhere")")
        }
    }

    func testSpreadAndBackToBackMatch() throws {
        let f = try load()
        for row in f.spreads {
            XCTAssertEqual(Schedule.spread(row[0].ints, count: row[1].int), row[2].ints,
                           "\(row[1].int) from \(row[0].ints)")
        }
        for row in f.backToBack {
            XCTAssertEqual(Schedule.hasBackToBack(row[0].ints), row[1].flag, "\(row[0].ints)")
        }
    }

    func testEveryHourLandsInTheSamePartOfTheDay() throws {
        for row in try load().hours {
            XCTAssertEqual(Schedule.anchorForHour(row[0].int).rawValue, row[1].str, "hour \(row[0].int)")
        }
    }

    func testAnchorsReadOutTheSameWay() throws {
        for row in try load().anchors {
            let set = row[0].isNull ? nil : row[0].list.compactMap { Anchor(rawValue: $0.str) }
            XCTAssertEqual(Schedule.primaryAnchor(set)?.rawValue, row[1].text, "primary of \(row[0])")
            XCTAssertEqual(Schedule.anchorLabel(set), row[2].text, "label of \(row[0])")
        }
    }

    func testTheNextTrainingDayIsNamedTheSame() throws {
        for row in try load().nexts {
            // the fixture carries the weekday the web computed from the date,
            // so this compares the rule and not two calendars
            XCTAssertEqual(Schedule.nextTrainingDay(row[0].ints, todayWeekday: row[2].int), row[3].text,
                           "\(row[0].ints) on \(row[1].str)")
        }
    }

    func testTheObservedAnchorIsJustAsCautious() throws {
        for row in try load().observed {
            let hours = row[0].ints
            let got = Schedule.observedAnchor(completedHours: hours)
            if row[1].isNull {
                XCTAssertNil(got, "\(hours) should say nothing")
            } else {
                let want = row[1].list
                XCTAssertEqual(got?.anchor.rawValue, want[0].str, "\(hours)")
                XCTAssertEqual(got?.count, want[1].int, "\(hours)")
                XCTAssertEqual(got?.total, want[2].int, "\(hours)")
            }
        }
    }
}
