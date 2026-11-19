//
// who is using the app, in three questions asked once.
//
// kept apart from SessionStore on purpose: a workout is a record of something
// that happened and belongs in a file you could hand to someone, a profile is
// a handful of settings. this one lives in UserDefaults because it is small,
// it is read on the first frame of the first screen, and losing it costs three
// taps rather than a year of training.

import Foundation
import Observation
import HabitaBullKit

struct Profile: Codable, Equatable {
    /// What to call her. Shown back on her own screens, never sent anywhere.
    var name = ""
    /// Why she lifts, in her words. Shown back on the days she doesn't feel
    /// like it, and never rewritten.
    var motivation = ""
    /// 0 = Sunday, matching the calendar and the rules package.
    ///
    /// Picked for her at the end of onboarding rather than asked for: three
    /// days, spread out, starting today. Asking a beginner which days they
    /// will train, before they have trained once, asks for a commitment they
    /// have no basis to make. The real week is offered after the first
    /// finished workout, and this is what it opens showing.
    var trainingDays: [Int] = []
    /// True once she has actually agreed to a week, rather than been given
    /// one. Onboarding fills `trainingDays` so the app always has an answer,
    /// but until this is true the home screen offers to build the week rather
    /// than pretending there is a plan she chose.
    var weekChosen = false
    /// The one number she is working towards, or nothing.
    ///
    /// One at a time on purpose. A list of goals is a list of things to feel
    /// behind on, and the screen that shows it is the screen she opens on a
    /// day she already does not want to train.
    var goal: Goal?
    /// Which day of the week is which workout, and what is in each one.
    ///
    /// Nil until she has agreed to a week. Everything before that is a quick
    /// workout, which has no plan by definition.
    var routine: Routine?
    var createdAt = Date.now

    /// Written by hand because the synthesised one throws on a key that is
    /// not there, even when the property has a default. A profile saved
    /// before a field existed must still load: `load()` reads a throw as "no
    /// profile", which would put onboarding in front of somebody who has
    /// already done it and lose the reason she typed.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        motivation = try c.decodeIfPresent(String.self, forKey: .motivation) ?? ""
        trainingDays = try c.decodeIfPresent([Int].self, forKey: .trainingDays) ?? []
        weekChosen = try c.decodeIfPresent(Bool.self, forKey: .weekChosen) ?? false
        goal = try c.decodeIfPresent(Goal.self, forKey: .goal)
        routine = try c.decodeIfPresent(Routine.self, forKey: .routine)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
    }

    init(name: String = "", motivation: String = "", trainingDays: [Int] = [],
         weekChosen: Bool = false, goal: Goal? = nil, routine: Routine? = nil,
         createdAt: Date = .now) {
        self.name = name
        self.motivation = motivation
        self.trainingDays = trainingDays
        self.weekChosen = weekChosen
        self.goal = goal
        self.routine = routine
        self.createdAt = createdAt
    }

    /// The reason, or nothing. Empty string and "not said" are the same thing
    /// everywhere else in the app, so they are the same thing here.
    var why: String? {
        let said = motivation.trimmingCharacters(in: .whitespacesAndNewlines)
        return said.isEmpty ? nil : said
    }
}

/// The one quiet line under the day's name on Today, or nothing.
///
/// Only the greeting lives here now. Her reason moved to a card of its own
/// further down the screen, where it is a sentence in her own words with the
/// bull above it rather than a dim line nobody reads.
///
/// Its own type because the rule is easy to get wrong, which is exactly what
/// happened: tying the greeting to "no workouts yet" meant somebody who
/// signed up on Sunday and first lifted on Wednesday was greeted all week.
enum TodayAside {
    static func line(for profile: Profile?, hasHistory: Bool,
                     now: Date = .now, calendar: Calendar = .current) -> String? {
        guard let profile, !hasHistory else { return nil }

        // the greeting belongs to the day she signed up and to no other day
        guard calendar.isDate(profile.createdAt, inSameDayAs: now) else { return nil }

        let name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : "Good to see you, \(name)."
    }
}

@Observable
final class ProfileStore {
    private(set) var profile: Profile?

    private let defaults: UserDefaults
    private let key = "profile"

    /// No profile means she has never answered the three questions, which is
    /// the only thing that puts onboarding on screen.
    var needsOnboarding: Bool { profile == nil }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // the UI tests ask for a known slate. -uitest-reset is the one that
        // clears everything, so the onboarding test sees a first run;
        // -uitest-onboarded puts a finished profile back, so every test about
        // logging a workout starts where it used to.
        let launched = ProcessInfo.processInfo.arguments
        if launched.contains("-uitest-reset") {
            defaults.removeObject(forKey: key)
            if launched.contains("-uitest-onboarded") {
                // -uitest-noweek is the phone that has answered the three
                // questions but never agreed to a week, which is the state
                // the home screen's first-run offer is written for
                let days = Self.testDays(launched)
                save(Profile(name: "Lucy", motivation: "It clears my head.",
                             trainingDays: days,
                             weekChosen: !launched.contains("-uitest-noweek"),
                             // only the rest day phone, which is the one that
                             // needs workouts to choose between. The others
                             // read today's plan off the session store, and
                             // handing them a routine would rename every
                             // workout in every test that has one
                             routine: launched.contains("-uitest-restday")
                                 ? Planner.plan(for: days) : nil,
                             createdAt: .now))
            }
            return
        }
        load()
    }

    /// The week a test phone opens with.
    ///
    /// Shifted onto today, the way onboarding does it, so the usual test
    /// phone is always on a day it trains: without the shift `placeDays`
    /// hands back Monday, Wednesday and Friday, and every test that waits for
    /// Start workout would fail on four days out of seven. -uitest-restday is
    /// the opposite ask, a week with today deliberately left out of it, which
    /// is the only way to see a rest day without waiting for one.
    private static func testDays(_ launched: [String]) -> [Int] {
        let today = Attendance.calendar().component(.weekday, from: .now) - 1
        if launched.contains("-uitest-restday") {
            return [(today + 2) % 7, (today + 4) % 7]
        }
        // -uitest-weekly is the once a week person, and her week has to say so
        // as well as her history: against a three day week, seven days off is
        // two workouts missed, which is a comeback and correctly so
        if launched.contains("-uitest-weekly") {
            return Schedule.placeDays(1, today: today)
        }
        return Schedule.placeDays(3, today: today)
    }

    func save(_ profile: Profile) {
        self.profile = profile
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: key)
    }

    /// Change one thing about her without rewriting the rest.
    func update(_ change: (inout Profile) -> Void) {
        var edited = profile ?? Profile()
        change(&edited)
        save(edited)
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let saved = try? JSONDecoder().decode(Profile.self, from: data) else { return }
        profile = saved
    }
}
