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
    var createdAt = Date.now

    /// The reason, or nothing. Empty string and "not said" are the same thing
    /// everywhere else in the app, so they are the same thing here.
    var why: String? {
        let said = motivation.trimmingCharacters(in: .whitespacesAndNewlines)
        return said.isEmpty ? nil : said
    }
}

/// The one quiet line under the day's name on Today, or nothing.
///
/// Its own type because the rule has three inputs and two of them are easy to
/// get wrong, which is exactly what happened: tying the greeting to "no
/// workouts yet" meant somebody who signed up on Sunday and first lifted on
/// Wednesday was greeted all week and never shown the reason she typed, on
/// precisely the days it was written for.
enum TodayAside {
    static func line(for profile: Profile?, hasHistory: Bool, finished: Bool,
                     now: Date = .now, calendar: Calendar = .current) -> String? {
        guard let profile else { return nil }

        // the greeting belongs to the day she signed up and to no other day
        let signedUpToday = calendar.isDate(profile.createdAt, inSameDayAs: now)
        let name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !hasHistory, signedUpToday, !name.isEmpty {
            return "Good to see you, \(name)."
        }

        // her reason, before the workout rather than after it. it is there to
        // get somebody to the gym, not to congratulate them
        guard !finished, let why = profile.why else { return nil }
        return "\u{201C}\(why)\u{201D}"
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
                save(Profile(name: "Lucy", motivation: "", trainingDays: Schedule.placeDays(3),
                             createdAt: .now))
            }
            return
        }
        load()
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
