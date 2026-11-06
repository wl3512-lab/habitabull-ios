//
// Day fit, against the web's answers.
//
// This is the rule that decides when a leg day has stopped being a leg day,
// what to call it instead, and which other days of the week are the same
// workout and should get a lift she added at the rack. Getting it wrong is
// quiet and expensive: a lift lands on one Monday and never on the Thursday
// that is the same workout, or a day silently renames itself.

import XCTest
@testable import HabitaBullKit

private struct Fixture: Decodable {
    let offTypes: [[J]], words: [[J]], beyond: [[J]], weeks: [[J]], sames: [[J]], shared: [[J]]
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
    var num: Double { if case .n(let v) = self { return v }; return 0 }
    var int: Int { Int(num) }
    var list: [J] { if case .a(let v) = self { return v }; return [] }
    var strings: [String] { list.map(\.str) }
    var isNull: Bool { if case .null = self { return true }; return false }
}

final class DayFitParityTests: XCTestCase {
    private var catalogue: [Lift] = []

    override func setUpWithError() throws {
        // the same library the planner fixture carries
        let url = try XCTUnwrap(Bundle.module.url(forResource: "planner", withExtension: "json"))
        struct Just: Decodable { let catalogue: [[J]] }
        catalogue = try JSONDecoder().decode(Just.self, from: Data(contentsOf: url)).catalogue.map {
            Lift(id: $0[0].str, name: $0[1].str, equipment: $0[2].str, primary: $0[3].str,
                 increment: $0[4].num, compound: $0[5].num == 1, heavy: $0[6].num == 1,
                 hold: $0[7].num == 1, cardio: $0[8].num == 1)
        }
    }

    private func load() throws -> Fixture {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "dayfit", withExtension: "json"))
        return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }

    private func lifts(_ ids: [String]) -> [PlannedLift] {
        ids.map { PlannedLift(exerciseId: $0, sets: 3, reps: 8, weight: 100) }
    }

    func testWhichLiftsDoNotFitTheDayAndWhatItIsCalledThen() throws {
        for row in try load().offTypes {
            let type = row[0].isNull ? nil : row[0].str
            let ids = row[1].strings
            let off = DayFit.offType(type, exercises: lifts(ids), catalogue: catalogue)
            XCTAssertEqual(off, row[2].strings, "off-type for \(type ?? "nil") with \(ids)")
            XCTAssertEqual(DayFit.mixedName(type, offIds: off, catalogue: catalogue), row[3].str,
                           "name for \(type ?? "nil") with \(ids)")
        }
    }

    func testWhatEachLiftAddsInAWord() throws {
        for row in try load().words {
            XCTAssertEqual(DayFit.groupWord(row[0].str, catalogue: catalogue), row[1].text, row[0].str)
        }
    }

    func testOnlyALiftThatChangesTheShapeOfTheDayCounts() throws {
        for row in try load().beyond {
            let type = row[0].isNull ? nil : row[0].str
            XCTAssertEqual(
                DayFit.offTypeBeyond(type, exercises: lifts(row[1].strings), before: row[2].strings, catalogue: catalogue),
                row[3].strings,
                "\(type ?? "nil") · \(row[1].strings) · had \(row[2].strings)")
        }
    }

    func testWhichDaysAreTheSameWorkoutAndWhatTheyInherit() throws {
        let f = try load()
        let weeks: [[WeekDay]] = f.weeks.map { week in
            week.map { entry in
                let row = entry.list
                return WeekDay(day: row[0].int, label: row[1].str,
                        dayType: row[2].isNull ? nil : row[2].str,
                        workoutId: row[3].isNull ? nil : row[3].str,
                        exercises: row[4].list.map {
                            PlannedLift(exerciseId: $0.list[0].str, sets: $0.list[1].int,
                                        reps: $0.list[2].int, weight: $0.list[3].num)
                        })
            }
        }

        for row in f.sames {
            let week = weeks[row[0].int]
            XCTAssertEqual(DayFit.sameWorkoutDays(week, at: row[1].int), row[2].list.map(\.int),
                           "week \(row[0].int), day index \(row[1].int)")
        }

        for row in f.shared {
            let week = weeks[row[0].int]
            let got = DayFit.shareLineup(week, from: row[1].int)
            let want = row[2].list
            XCTAssertEqual(got.count, want.count)
            for (day, expected) in zip(got, want) {
                let rows = expected.list
                XCTAssertEqual(day.exercises.count, rows.count,
                               "week \(row[0].int) from \(row[1].int): lift count")
                for (lift, e) in zip(day.exercises, rows) {
                    XCTAssertEqual(lift.exerciseId, e.list[0].str, "week \(row[0].int) from \(row[1].int)")
                    // the numbers each day keeps are the point of this rule
                    XCTAssertEqual(lift.sets, e.list[1].int, "\(lift.exerciseId) sets")
                    XCTAssertEqual(lift.reps, e.list[2].int, "\(lift.exerciseId) reps")
                    XCTAssertEqual(lift.weight, e.list[3].num, accuracy: 0.0001, "\(lift.exerciseId) weight")
                }
            }
        }
    }
}
