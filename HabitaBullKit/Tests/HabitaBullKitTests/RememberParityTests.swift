//
// The plan keeping up with the workouts.
//
// A day's lifts are where the next session comes from, so a lift added at the
// rack has to reach the plan or it is forgotten by next week — and it has to
// reach the other days that are the same workout, or Monday's leg day and
// Thursday's quietly drift apart.
//
// Checked against the web's answers to ten sessions: the same lifts heavier,
// one added, one dropped, a name no day has, the right name on the wrong
// weekday, a quick workout, a day rebuilt around an injury, an empty session,
// a lift with no sets in it, and the second of two days called Full body A.

import XCTest
@testable import HabitaBullKit

private let utc = TimeZone(identifier: "UTC")!

private struct Fixture: Decodable {
    let week: [[J]]
    let cases: [Case]

    struct Case: Decodable {
        let name: String
        let session: [J]
        let after: [[J]]
        let shared: [[J]]
    }
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
    var str: String { if case .s(let v) = self { return v }; return "" }
    var num: Double { if case .n(let v) = self { return v }; return 0 }
    var int: Int { Int(num) }
    var flag: Bool { if case .b(let v) = self { return v }; return false }
    var list: [J] { if case .a(let v) = self { return v }; return [] }
}

final class RememberParityTests: XCTestCase {
    private func load() throws -> Fixture {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "remember", withExtension: "json"))
        return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }

    private func week(_ rows: [[J]]) -> [PlannedDay] {
        rows.map { row in
            PlannedDay(day: row[0].int, label: row[1].str, dayType: "full-body",
                       exercises: row[2].list.map {
                           PlannedLift(exerciseId: $0.list[0].str, sets: $0.list[1].int,
                                       reps: $0.list[2].int, weight: $0.list[3].num)
                       })
        }
    }

    private func check(_ got: [PlannedDay], _ want: [[J]], _ what: String) {
        XCTAssertEqual(got.count, want.count, what)
        for (day, row) in zip(got, want) {
            XCTAssertEqual(day.day, row[0].int, "\(what): weekday")
            XCTAssertEqual(day.label, row[1].str, "\(what): name")
            let lifts = row[2].list
            XCTAssertEqual(day.exercises.count, lifts.count, "\(what): \(day.label) lift count")
            for (lift, e) in zip(day.exercises, lifts) {
                XCTAssertEqual(lift.exerciseId, e.list[0].str, "\(what): \(day.label)")
                XCTAssertEqual(lift.sets, e.list[1].int, "\(what): \(lift.exerciseId) sets")
                XCTAssertEqual(lift.reps, e.list[2].int, "\(what): \(lift.exerciseId) reps")
                XCTAssertEqual(lift.weight, e.list[3].num, accuracy: 0.0001, "\(what): \(lift.exerciseId) weight")
            }
        }
    }

    func testTheWeekKeepsUpWithWhatSheActuallyDid() throws {
        let f = try load()
        let start = week(f.week)
        XCTAssertEqual(f.cases.count, 10)

        for c in f.cases {
            let s = c.session
            let session = TrainingSession(
                date: s[0].str,
                label: s[1].str,
                lifts: s[3].list.map { lift in
                    LoggedLift(exerciseId: lift.list[0].str, sets: lift.list[1].list.map {
                        LoggedSet(weight: $0.list[0].num, reps: $0.list[1].int, done: $0.list[2].flag)
                    })
                },
                oneOff: s[2].flag)

            let after = Planner.remember(session, in: start, zone: utc)
            check(after, c.after, c.name)

            // and then out to the other days that are the same workout
            let changed = after.indices.first { after[$0] != start[$0] }
            let shared = changed.map { DayFit.shareLineup(after, from: $0) } ?? after
            check(shared, c.shared, "\(c.name), shared across the week")
        }
    }

    func testAQuickWorkoutIsNotADecisionAboutThatDay() throws {
        let start = week(try load().week)
        let improvised = TrainingSession(
            date: "2026-11-02", label: "Full body A",
            lifts: [LoggedLift(exerciseId: "db-curl", sets: [LoggedSet(weight: 25, reps: 10, done: true)])],
            oneOff: true)
        XCTAssertEqual(Planner.remember(improvised, in: start, zone: utc), start)
    }
}
