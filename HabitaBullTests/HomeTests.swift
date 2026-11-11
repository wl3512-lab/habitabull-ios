//
// what the home screen is for on a given day, without a screen in front of it.
//
// The three shapes are not decoration: each one has a different primary
// action, and getting the choice wrong means either asking a beginner to set
// up a week before she has lifted once, or offering a quick workout to
// somebody who already has a plan on the card in front of her.

import XCTest
import HabitaBullKit
@testable import HabitaBull

final class HomeTests: XCTestCase {
    private var file: URL!
    private var store: SessionStore!

    override func setUp() {
        file = URL.temporaryDirectory.appending(path: "home-\(UUID().uuidString).json")
        store = SessionStore(fileURL: file)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: file)
    }

    private func newcomer() -> Profile { Profile(name: "Lucy", trainingDays: [1, 3, 5]) }
    private func settled() -> Profile {
        Profile(name: "Lucy", trainingDays: [1, 3, 5], weekChosen: true)
    }

    // MARK: - which screen today is

    func testBeforeSheAgreesToAWeekTheScreenAsksForOneSession() {
        // the finding the screen is built on: people log a workout before
        // they will set anything up. onboarding placed days for her, but
        // placed is not agreed.
        XCTAssertEqual(Home.shape(profile: newcomer(), today: nil), .firstWorkout)
    }

    func testOnceSheHasAgreedToAWeekTheScreenShowsThePlan() {
        XCTAssertEqual(Home.shape(profile: settled(), today: nil, fallback: "Leg day"),
                       .plan("Leg day"))
    }

    func testAWorkoutOpenTodayOutranksTheFirstRunOffer() {
        // she took the quick workout. the screen's job is now finishing it,
        // not offering her another one.
        store.startQuickWorkout()
        XCTAssertEqual(Home.shape(profile: newcomer(), today: store.today),
                       .plan("Quick workout"))
    }

    func testAFinishedDayCountsTheLiftsAndStopsAsking() {
        store.startWorkout()
        store.logSet(onExercise: 0, weight: 45, reps: 8)
        store.finishWorkout()
        XCTAssertEqual(Home.shape(profile: settled(), today: store.today), .done(lifts: 1))
    }

    func testNoProfileAtAllIsStillAFirstRun() {
        XCTAssertEqual(Home.shape(profile: nil, today: nil), .firstWorkout)
    }

    func testTheHeadlineSaysWhatTheScreenIsFor() {
        XCTAssertEqual(Home.headline(.firstWorkout), "Your first workout")
        XCTAssertEqual(Home.headline(.plan("Push day")), "Push day")
        XCTAssertEqual(Home.headline(.done(lifts: 2)), "Logged")
    }

    // MARK: - a profile written before the week existed

    func testAProfileSavedBeforeTheWeekExistedStillLoads() throws {
        // the synthesised decoder throws on a missing key even when the
        // property has a default, and a throw here reads as "no profile",
        // which would put onboarding back in front of somebody who has
        // already done it.
        let old = #"{"name":"Lucy","motivation":"It clears my head.","trainingDays":[1,3,5],"createdAt":780000000}"#
        let profile = try JSONDecoder().decode(Profile.self, from: Data(old.utf8))

        XCTAssertEqual(profile.name, "Lucy")
        XCTAssertEqual(profile.why, "It clears my head.")
        XCTAssertEqual(profile.trainingDays, [1, 3, 5])
        XCTAssertFalse(profile.weekChosen, "a week she was never asked about is not a week she chose")
    }

    func testChoosingAWeekSurvivesTheAppClosing() {
        let defaults = UserDefaults(suiteName: "home-\(UUID().uuidString)")!
        let store = ProfileStore(defaults: defaults)
        store.save(newcomer())
        store.update {
            $0.trainingDays = [2, 5]
            $0.weekChosen = true
        }

        let later = ProfileStore(defaults: defaults)
        XCTAssertEqual(later.profile?.trainingDays, [2, 5])
        XCTAssertTrue(later.profile?.weekChosen == true)
    }

    // MARK: - the week she has actually kept

    func testShowingUpCountsEvenWhenYouStopEarly() {
        store.startWorkout()
        store.logSet(onExercise: 0, weight: 45, reps: 8)
        // no finishWorkout: she left partway through
        let record = store.sessions[0].asRecord
        XCTAssertFalse(record.completed)
        XCTAssertTrue(record.loggedSet)
        XCTAssertTrue(record.attended, "two sets and a walk out is still a day you showed up")
    }

    func testAWorkoutOpenedAndLeftEmptyIsNotADayYouShowedUp() {
        store.startWorkout()
        let record = store.sessions[0].asRecord
        XCTAssertFalse(record.attended)
    }

    func testTodayIsMarkedOnTheStripAndTheWeekIsSevenDays() {
        let strip = store.weekStrip(trainingDays: [1, 3, 5])
        XCTAssertEqual(strip.count, 7)
        XCTAssertEqual(strip.filter(\.isToday).count, 1)
        XCTAssertEqual(strip.filter(\.planned).map(\.index), [1, 3, 5])
    }

    func testADayYouTrainedOnReadsAsTrained() {
        store.startWorkout()
        store.logSet(onExercise: 0, weight: 45, reps: 8)
        store.finishWorkout()

        let strip = store.weekStrip(trainingDays: [])
        let today = strip.first(where: \.isToday)
        XCTAssertEqual(today?.trained, true)
        XCTAssertEqual(strip.filter(\.trained).count, 1, "one session is one filled circle")
    }
}
