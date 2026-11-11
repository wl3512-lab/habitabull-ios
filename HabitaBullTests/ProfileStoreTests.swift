//
// the three answers, and what the app does with them.

import XCTest
import HabitaBullKit
@testable import HabitaBull

final class ProfileStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!

    override func setUp() {
        super.setUp()
        suite = "profile-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testAPhoneThatHasNeverRunTheAppAsksTheQuestions() {
        XCTAssertTrue(ProfileStore(defaults: defaults).needsOnboarding)
    }

    func testAnsweringOnceIsAnsweringForGood() {
        let first = ProfileStore(defaults: defaults)
        first.save(Profile(name: "Lucy", motivation: "It clears my head.",
                           trainingDays: [1, 3, 5], createdAt: .now))

        let later = ProfileStore(defaults: defaults)
        XCTAssertFalse(later.needsOnboarding)
        XCTAssertEqual(later.profile?.name, "Lucy")
        XCTAssertEqual(later.profile?.why, "It clears my head.")
        XCTAssertEqual(later.profile?.trainingDays, [1, 3, 5])
    }

    func testSkippingEveryQuestionIsStillAnAnswer() {
        // Skip on both screens writes a profile with nothing in it, which is
        // what stops the app asking again tomorrow.
        let store = ProfileStore(defaults: defaults)
        store.save(Profile())
        XCTAssertFalse(ProfileStore(defaults: defaults).needsOnboarding)
    }

    func testAReasonOfNothingIsNoReason() {
        XCTAssertNil(Profile(motivation: "").why)
        XCTAssertNil(Profile(motivation: "   \n ").why, "whitespace is not an answer")
        XCTAssertEqual(Profile(motivation: "  It clears my head. ").why, "It clears my head.")
    }

    func testChangingOneThingKeepsTheRest() {
        let store = ProfileStore(defaults: defaults)
        store.save(Profile(name: "Lucy", motivation: "It clears my head.", trainingDays: [1, 3, 5]))
        store.update { $0.motivation = "I want to feel strong." }

        XCTAssertEqual(store.profile?.name, "Lucy")
        XCTAssertEqual(store.profile?.trainingDays, [1, 3, 5])
        XCTAssertEqual(store.profile?.why, "I want to feel strong.")
    }

    // MARK: - the line under today's workout

    private func signedUp(_ daysAgo: Int, name: String = "Lucy",
                          why: String = "It clears my head.") -> Profile {
        Profile(name: name, motivation: why, trainingDays: [1, 3, 5],
                createdAt: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!)
    }

    func testTheDayYouSignUpYouAreGreetedRatherThanQuoted() {
        XCTAssertEqual(TodayAside.line(for: signedUp(0), hasHistory: false, finished: false),
                       "Good to see you, Lucy.")
    }

    func testTheDayAfterYouSignUpYouGetYourOwnWordsBack() {
        // the bug an independent review found: tying the greeting to "no
        // workouts yet" greeted her every day until she first lifted, which
        // are exactly the days the reason was written for
        XCTAssertEqual(TodayAside.line(for: signedUp(1), hasHistory: false, finished: false),
                       "\u{201C}It clears my head.\u{201D}")
    }

    func testOnceYouHaveTrainedTheGreetingIsOver() {
        XCTAssertEqual(TodayAside.line(for: signedUp(0), hasHistory: true, finished: false),
                       "\u{201C}It clears my head.\u{201D}")
    }

    func testAFinishedDayIsNotTheMomentForAPepTalk() {
        XCTAssertNil(TodayAside.line(for: signedUp(3), hasHistory: true, finished: true))
    }

    func testSayingNothingAtAllShowsNothingAtAll() {
        XCTAssertNil(TodayAside.line(for: Profile(), hasHistory: false, finished: false),
                     "no name and no reason is a blank line, not an empty quote")
        XCTAssertNil(TodayAside.line(for: nil, hasHistory: false, finished: false))
    }

    func testNoNameStillGetsTheReasonOnTheFirstDay() {
        let shy = signedUp(0, name: "  ")
        XCTAssertEqual(TodayAside.line(for: shy, hasHistory: false, finished: false),
                       "\u{201C}It clears my head.\u{201D}")
    }

    func testTheWeekSheIsOfferedLaterStartsToday() {
        // Three days, spread out, with today as the first one: signing up on a
        // Thursday and being told "rest day" is a poor first sentence.
        for today in 0..<7 {
            let days = Schedule.placeDays(3, today: today)
            XCTAssertEqual(days.count, 3)
            XCTAssertTrue(days.contains(today), "the first session is today, whatever day that is")
            XCTAssertFalse(Schedule.hasBackToBack(days), "three days in a week can all be apart")
        }
    }
}
