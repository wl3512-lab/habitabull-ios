//
// the record screen's words, and the one date rule underneath them.
//
// Both of these came out of an independent review rather than out of a bug
// report, which is the cheap way to find them: a streak of one claiming a
// session that has not happened, and a phone whose calendar files a workout
// under a year the attendance rules never look in.

import XCTest
import HabitaBullKit
@testable import HabitaBull

final class RecordTests: XCTestCase {

    // MARK: - what the big line says

    func testNoHistoryAtAllIsTheOnlyNothingYet() {
        XCTAssertEqual(Record.headline(sessions: 0, weeks: 0), "Nothing yet")
    }

    func testABreakDoesNotEraseWhatSheAlreadyDid() {
        // the streak is gone, the six days are not
        XCTAssertEqual(Record.headline(sessions: 6, weeks: 0), "6 days logged")
        XCTAssertEqual(Record.headline(sessions: 1, weeks: 0), "1 day logged")
    }

    func testARunOfOneNeverClaimsAWorkoutThisWeek() {
        // streakWeeks holds last week's run until this week's first session,
        // so "this week" would be a sentence about something that has not
        // happened
        XCTAssertEqual(Record.headline(sessions: 3, weeks: 1), "1 week running")
    }

    func testARunOfSeveralCountsTheWeeks() {
        XCTAssertEqual(Record.headline(sessions: 9, weeks: 3), "3 weeks running")
    }

    // MARK: - one calendar

    func testAWorkoutIsFiledUnderTheDayTheRulesWillLookFor() {
        // the app writes session dates with dayString and the rules read them
        // with Attendance.day. on a phone set to a non-Gregorian calendar
        // these used to disagree, and every day she trained read as a day she
        // missed
        XCTAssertEqual(dayString(), Attendance.day(.now, Attendance.calendar()))
    }

    /// A phone that was already in use when the calendar bug was fixed.
    func testAWorkoutFiledUnderThePhonesOwnCalendarIsFoundAgain() throws {
        let file = URL.temporaryDirectory.appending(path: "record-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }

        // what a phone set to the Buddhist calendar used to write: the year
        // 2569, and a startedAt that is simply today
        let started = ISO8601DateFormatter().string(from: .now)
        let saved = """
        [{"id":"old","date":"2569-11-11","label":"Leg day","exercises":[],
          "startedAt":"\(started)"}]
        """
        try Data(saved.utf8).write(to: file)

        let store = SessionStore(fileURL: file)
        XCTAssertEqual(store.sessions.first?.date, dayString(),
                       "a day she trained is still filed under a year that never happened")
        XCTAssertNotNil(store.today, "the workout she left open cannot be reached")
    }

    /// An Indian-calendar phone, whose year looks like a perfectly ordinary
    /// one and so cannot be spotted by reading the year.
    func testACalendarWhoseYearsLookNormalIsRepairedToo() throws {
        let file = URL.temporaryDirectory.appending(path: "record-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let started = ISO8601DateFormatter().string(from: .now)
        let saved = """
        [{"id":"old","date":"1948-08-20","label":"Leg day","exercises":[],
          "startedAt":"\(started)"}]
        """
        try Data(saved.utf8).write(to: file)

        XCTAssertEqual(SessionStore(fileURL: file).sessions.first?.date, dayString())
    }

    /// Somebody who flew somewhere. A day either side of the instant it
    /// started is a time zone, not a calendar, and nothing to repair.
    func testADayOutByATimeZoneIsLeftAlone() throws {
        let file = URL.temporaryDirectory.appending(path: "record-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let yesterday = dayString(Date.now.addingTimeInterval(-86_400))
        let started = ISO8601DateFormatter().string(from: .now)
        let saved = """
        [{"id":"old","date":"\(yesterday)","label":"Leg day","exercises":[],
          "startedAt":"\(started)"}]
        """
        try Data(saved.utf8).write(to: file)

        XCTAssertEqual(SessionStore(fileURL: file).sessions.first?.date, yesterday)
    }

    /// The widest the world gets: Kiritimati is 25 hours ahead of Pago Pago,
    /// so the same instant can be the 11th on one island and the 9th on the
    /// other. That date was right when it was written.
    func testADayOutByTheDateLineIsStillHerDay() throws {
        let file = URL.temporaryDirectory.appending(path: "record-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let twoDaysOff = dayString(Date.now.addingTimeInterval(-2 * 86_400))
        let started = ISO8601DateFormatter().string(from: .now)
        let saved = """
        [{"id":"old","date":"\(twoDaysOff)","label":"Leg day","exercises":[],
          "startedAt":"\(started)"}]
        """
        try Data(saved.utf8).write(to: file)

        XCTAssertEqual(SessionStore(fileURL: file).sessions.first?.date, twoDaysOff)
    }

    func testADayLoggedTodayFillsTodaysCircle() {
        let file = URL.temporaryDirectory.appending(path: "record-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let store = SessionStore(fileURL: file)
        store.startWorkout()
        store.logSet(onExercise: 0, weight: 95, reps: 8)

        let today = store.weekStrip(trainingDays: []).first(where: \.isToday)
        XCTAssertEqual(today?.trained, true, "the day she trained is not the day it was stored under")
    }
}
