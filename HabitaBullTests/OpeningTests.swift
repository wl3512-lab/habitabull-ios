//
// what the launch screen says, without a screen in front of it.
//
// It is the first thing she reads, so the two ways it can lie both matter:
// calling a day she planned to train a rest day, and calling a day a rest day
// when she never agreed to a week at all. It reads `Home.shape`, so these
// also check that the splash and the screen behind it cannot disagree.

import XCTest
import HabitaBullKit
@testable import HabitaBull

final class OpeningTests: XCTestCase {
    private let cal = Attendance.calendar()
    private var file: URL!
    private var store: SessionStore!

    override func setUp() {
        file = URL.temporaryDirectory.appending(path: "opening-\(UUID().uuidString).json")
        store = SessionStore(fileURL: file)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: file)
    }

    /// 2026-11-08 is a Sunday, which is weekday 0 everywhere in this app.
    private func sunday() -> Date { Attendance.date("2026-11-08", cal)! }
    private func monday() -> Date { Attendance.date("2026-11-09", cal)! }

    private func settled(_ days: [Int]) -> Profile {
        Profile(name: "Lucy", motivation: "It clears my head.",
                trainingDays: days, weekChosen: true)
    }

    // MARK: - which day this is

    func testADaySheChoseIsAWorkoutDay() {
        XCTAssertEqual(Launch.opening(profile: settled([0, 3, 5]), today: nil,
                                      now: sunday(), calendar: cal), .workout)
    }

    func testADaySheDidNotChooseIsARestDay() {
        XCTAssertEqual(Launch.opening(profile: settled([0, 3, 5]), today: nil,
                                      now: monday(), calendar: cal), .rest)
    }

    func testSundayIsDayZeroAndNotDayOne() {
        // the off-by-one that would move her whole week a day to the left
        XCTAssertEqual(Launch.opening(profile: settled([1]), today: nil,
                                      now: sunday(), calendar: cal), .rest)
        XCTAssertEqual(Launch.opening(profile: settled([1]), today: nil,
                                      now: monday(), calendar: cal), .workout)
    }

    func testADayAlreadyLoggedSaysSoAndNotRest() {
        store.startWorkout()
        store.logSet(onExercise: 0, weight: 45, reps: 8)
        store.finishWorkout()
        // she trained on a day she had not picked. telling her to rest on the
        // day she just lifted would be the app not watching.
        XCTAssertEqual(Launch.opening(profile: settled([0]), today: store.today,
                                      now: monday(), calendar: cal), .done)
    }

    func testAWorkoutLeftOpenIsStillAWorkoutDay() {
        store.startQuickWorkout()
        XCTAssertEqual(Launch.opening(profile: settled([0]), today: store.today,
                                      now: monday(), calendar: cal), .workout)
    }

    func testAWeekSheWasGivenRatherThanChoseHasNoRestDays() {
        // onboarding places days so the app has an answer. calling the other
        // four rest days would be claiming she decided something she never
        // decided.
        let placed = Profile(name: "Lucy", trainingDays: [1, 3, 5], weekChosen: false)
        XCTAssertEqual(Launch.opening(profile: placed, today: nil,
                                      now: monday(), calendar: cal), .open)
    }

    func testNoProfileAtAllIsStillAnHonestScreen() {
        XCTAssertEqual(Launch.opening(profile: nil, today: nil,
                                      now: monday(), calendar: cal), .open)
    }

    func testTheDayIsReadInTheAppsCalendarAndNotThePhones() {
        // a phone set to the Buddhist calendar has a different era and year.
        // the weekday has to come out the same, or the whole week slides.
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = .current
        XCTAssertEqual(Launch.opening(profile: settled([0]), today: nil,
                                      now: sunday(), calendar: buddhist), .workout)
    }

    // MARK: - the splash and the screen behind it

    func testTheLaunchScreenAndTheHomeScreenNeverDisagree() {
        let profile = settled([0])
        for day in [sunday(), monday()] {
            let shape = Home.shape(profile: profile, today: nil, now: day, calendar: cal)
            let opening = Launch.opening(profile: profile, today: nil, now: day, calendar: cal)
            XCTAssertEqual(shape == .rest, opening == .rest,
                           "one of them calls \(day) a rest day and the other does not")
        }
    }

    // MARK: - what it says

    func testEachDayHasItsOwnWords() {
        XCTAssertEqual(Launch.headline(.workout), "Workout day")
        XCTAssertEqual(Launch.headline(.rest), "Rest day")
        XCTAssertEqual(Launch.headline(.done), "Done for today")
        XCTAssertEqual(Launch.headline(.open), "Up to you")
    }

    func testARestDaySaysWhyItIsThereAndAWorkoutDayNeedsNothing() {
        XCTAssertNotNil(Launch.note(.rest), "a rest day read alone looks like a missed day")
        XCTAssertNotNil(Launch.note(.open))
        XCTAssertNil(Launch.note(.workout))
        XCTAssertNil(Launch.note(.done))
    }
}
