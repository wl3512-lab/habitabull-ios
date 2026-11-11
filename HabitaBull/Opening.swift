//
// the screen the app opens on, which answers one question before she asks it:
// is today a workout day or a rest day?
//
// A launch screen has to show something, and the two candidates were her
// reason and the day's shape. The day's shape wins the headline, because that
// is the thing she opened the app to find out. Her reason goes underneath it
// rather than on the home screen, which is where it belongs: the moment she
// is deciding whether to go is the moment it does any work.
//
// What it says is not decided here: it is read off `Home.shape`, the same
// answer the home screen behind it is drawing. Two rules would drift, and the
// day they drifted the app would say rest day over a Start workout button.

import SwiftUI
import HabitaBullKit

enum Opening: Equatable {
    /// One of her days, nothing logged yet.
    case workout
    /// A day she did not pick. Not a missed day, a day off.
    case rest
    /// She already turned up today.
    case done
    /// No week agreed to yet, so no day is a rest day: it is up to her.
    case open
}

enum Launch {
    static func opening(profile: Profile?, today: Session?, now: Date = .now,
                        calendar: Calendar = Attendance.calendar()) -> Opening {
        switch Home.shape(profile: profile, today: today, now: now, calendar: calendar) {
        case .done: .done
        case .rest: .rest
        // no week agreed to yet, so no day is a rest day and none is assigned
        case .firstWorkout: .open
        // a workout open and unfinished is still today's workout
        case .plan: .workout
        }
    }

    static func headline(_ opening: Opening) -> String {
        switch opening {
        case .workout: "Workout day"
        case .rest: "Rest day"
        case .done: "Done for today"
        case .open: "Up to you"
        }
    }

    /// The quiet line under the headline, where the headline on its own could
    /// be read as a telling-off.
    static func note(_ opening: Opening) -> String? {
        switch opening {
        case .rest: "Rest is part of the training."
        case .open: "No week yet. Lift when you can."
        case .workout, .done: nil
        }
    }

    static func pose(_ opening: Opening) -> Bull.Pose {
        switch opening {
        case .workout: .show
        case .rest: .rest
        case .done: .cheer
        case .open: .stand
        }
    }
}

struct OpeningView: View {
    let opening: Opening
    let why: String?
    let done: () -> Void

    /// Long enough to read a short line, short enough that nobody reaches to
    /// tap through it. A tap goes through anyway.
    private var wait: Duration {
        ProcessInfo.processInfo.arguments.contains("-uitest-hold-opening")
            ? .seconds(30) : .seconds(1.6)
    }

    /// A bull this big is the first thing to give up its space when the text
    /// needs it: the words are the screen, he is the welcome.
    @Environment(\.dynamicTypeSize) private var typeSize

    /// The bull, the day, and her own words under it.
    private var said: some View {
        VStack(spacing: 0) {
            Bull(pose: Launch.pose(opening), size: typeSize.isAccessibilitySize ? 84 : 132)

            Text(Launch.headline(opening))
                .font(.figure)
                .foregroundStyle(.fg)
                .multilineTextAlignment(.center)
                .padding(.top, 10)

            if let note = Launch.note(opening) {
                Text(note)
                    .font(.bodyText)
                    .foregroundStyle(.dim)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }

            if let why {
                SectionLabel(text: "You work out because")
                    .padding(.top, 34)
                Text("\u{201C}\(why)\u{201D}")
                    .font(.titleText)
                    .foregroundStyle(.brandCyan)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
        }
    }

    var body: some View {
        // it scrolls, and it is centred until it cannot be. at the largest
        // accessibility sizes a fixed stack silently truncates the headline to
        // "Workout..." and cuts her own sentence off halfway, which is the one
        // thing on the screen that is hers
        GeometryReader { proxy in
            ScrollView {
                said
                    .padding(32)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                    .contentShape(.rect)
                    .onTapGesture(perform: done)
                    // one named element around the whole screen, so a test can
                    // say "the launch screen is up" and "it is gone" without
                    // naming its words
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("opening")
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(.ground)
        .ignoresSafeArea()
        .task {
            // a cancelled sleep means the screen is already gone: calling
            // done() then would fight whatever replaced it
            do { try await Task.sleep(for: wait) } catch { return }
            done()
        }
    }
}

#Preview {
    OpeningView(opening: .workout, why: "It clears my head.") {}
}
