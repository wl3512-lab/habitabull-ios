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

    /// Her best set of a day, where two sets were the same weight.
    ///
    /// The day card and the progress chart each had their own idea of which
    /// set was the better one. The chart broke a tie on reps, the card did
    /// not, so a day of 135 for 5 and 135 for 8 had the card printing "135 lb
    /// x 5" as her best while the chart marked the 8. One rule now, in the
    /// package, asked by both. Found by a codex audit 2026-11-17.
    func testTheBestSetAtOneWeightIsTheOneWithMoreReps() {
        let squat = LoggedExercise(exerciseId: "back-squat", sets: [
            LoggedSet(weight: 135, reps: 5, done: true),
            LoggedSet(weight: 135, reps: 8, done: true),
        ])
        XCTAssertEqual(squat.best(of: squat.sets)?.reps, 8)

        // and heavier is still better however few reps it was
        let mixed = LoggedExercise(exerciseId: "back-squat", sets: [
            LoggedSet(weight: 135, reps: 8, done: true),
            LoggedSet(weight: 145, reps: 1, done: true),
        ])
        XCTAssertEqual(mixed.best(of: mixed.sets)?.weight, 145)
    }

    /// And on a machine that counts help: less help is better, and at the
    /// same help the set with more reps is.
    func testTheBestSetOnAHelpMachineIsTheOneWithLeastHelpThenMostReps() {
        let pullUp = LoggedExercise(exerciseId: "assisted-pull-up", sets: [
            LoggedSet(weight: 30, reps: 8, done: true),
            LoggedSet(weight: 20, reps: 5, done: true),
        ])
        XCTAssertEqual(pullUp.best(of: pullUp.sets)?.weight, 20, "less help is the better set")

        let tied = LoggedExercise(exerciseId: "assisted-pull-up", sets: [
            LoggedSet(weight: 20, reps: 5, done: true),
            LoggedSet(weight: 20, reps: 9, done: true),
        ])
        XCTAssertEqual(tied.best(of: tied.sets)?.reps, 9)
    }


    // MARK: - what the big line says

    /// A lift of her own keeps every word of its name.
    ///
    /// The id is the name with "custom-" in front of it, and reading the name
    /// back took every "custom-" out rather than the one on the front. So a
    /// lift she called "Custom Press" was custom-custom-press and read back
    /// as "Press": the sets step said one name and the workout under it said
    /// another. Found by a codex audit 2026-11-17.
    func testALiftOfHerOwnKeepsEveryWordOfItsName() {
        XCTAssertEqual(customLiftId("Custom Press"), "custom-custom-press")
        XCTAssertEqual(liftName("custom-custom-press"), "Custom Press")
        XCTAssertEqual(liftName("custom-cable-crossover"), "Cable Crossover")
        // and a lift the library knows is still named by the library
        XCTAssertEqual(liftName("back-squat"), "Back Squat")
    }

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
