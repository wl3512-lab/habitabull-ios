//
// the home screen. it answers one question: what do i do right now?
//
// Before she has agreed to a week the answer is "one session, no setup",
// which is the finding the whole screen is built on: people log a workout
// before they will set anything up. After that the answer is the day's plan.
// Either way the week she has actually kept sits under it, because turning
// up is the thing the app is about and it used to be invisible here.

import SwiftUI
import HabitaBullKit

struct TodayView: View {
    @Environment(SessionStore.self) private var store
    @Environment(ProfileStore.self) private var profiles
    /// Which place the bar is standing on. A binding so the home screen can
    /// hand the user to another place without owning the choice; defaulted so
    /// a preview or a test can show the screen on its own.
    @Binding var place: Place
    @State private var logging = false
    @State private var buildingWeek = false

    init(place: Binding<Place> = .constant(.today)) { _place = place }

    private var session: Session? { store.today }
    private var finished: Bool { session?.completedAt != nil }
    private var shape: HomeShape { Home.shape(profile: profiles.profile, today: session) }

    /// Her reason rises above the action on the day it is written for, and
    /// sits below it on every other day.
    private var raised: Bool { shape == .firstWorkout }

    /// The greeting on the day she signed up, or nothing. Her reason is not
    /// here any more: it has a card of its own further down the screen.
    private var aside: String? {
        TodayAside.line(for: profiles.profile, hasHistory: !store.sessions.isEmpty)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel(text: Date.now.formatted(.dateTime.weekday(.wide).month().day()))

                    Text(Home.headline(shape))
                        .font(.figure)
                        .foregroundStyle(.fg)
                        .padding(.top, 14)

                    if let aside {
                        Text(aside)
                            .font(.emphasis)
                            .foregroundStyle(.brandCyan)
                            .padding(.top, 4)
                    }

                    unfinishedCard

                    // Two orders, because the two screens are answering
                    // different questions. With no week yet the reason comes
                    // first and the plan is an offer at the bottom. With a
                    // plan, what you are about to lift sits under its own
                    // name, where you look for it, and the reason waits
                    // below the action it is there to get you through.
                    if raised {
                        reasonCard.padding(.top, 26)
                        action.padding(.top, 26)
                        weekStrip.padding(.top, 34)
                        todaysLifts.padding(.top, 34)
                    } else {
                        todaysLifts.padding(.top, 22)
                        action.padding(.top, 26)
                        weekStrip.padding(.top, 34)
                        reasonCard.padding(.top, 34)
                    }

                    if store.saveFailed {
                        Text("This phone isn't saving right now.")
                            .font(.bodyText)
                            .foregroundStyle(.fault)
                            .padding(.top, 20)
                    }

                    #if DEBUG
                    if session != nil {
                        Pill(title: "Start over", variant: .ghost) { store.resetToday() }
                            .padding(.top, 20)
                    }
                    #endif
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.ground)
            .standingOn(.today) { place = $0 }
            .navigationDestination(isPresented: $logging) { LogView() }
            .navigationDestination(isPresented: $buildingWeek) { WeekView() }
        }
        .tint(.brandCyan)
    }

    private var reasonCard: some View {
        ReasonCard(profile: profiles.profile, raised: raised) { said in
            profiles.update { $0.motivation = said }
        }
    }

    // MARK: - the one action

    @ViewBuilder private var action: some View {
        switch shape {
        case .done(let lifts):
            // no orange here on purpose: turning up was the job, and inventing
            // one more thing to do argues against the app's own point
            Card {
                VStack(spacing: 12) {
                    Bull(pose: .cheer, size: 112)
                    Text("\(amount(lifts, "lift")) done. See you next time.")
                        .font(.emphasis)
                        .foregroundStyle(.fg)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }

        case .firstWorkout:
            VStack(alignment: .leading, spacing: 12) {
                Pill(title: "Start a quick workout") {
                    store.startQuickWorkout()
                    logging = true
                }
                // explained only here, on the one screen where these words
                // have nothing around them to make sense of
                Text("No plan needed. Pick a lift, log it, pick the next one.")
                    .font(.bodyText)
                    .foregroundStyle(.dim)
            }

        case .plan:
            VStack(spacing: 10) {
                Pill(title: session == nil ? "Start workout" : "Continue workout") {
                    store.startWorkout()
                    logging = true
                }
                if session == nil {
                    Pill(title: "Quick workout", variant: .ghost) {
                        store.startQuickWorkout()
                        logging = true
                    }
                }
            }
        }
    }

    // MARK: - the week she has actually kept

    private var days: [StripDay] {
        store.weekStrip(trainingDays: profiles.profile?.trainingDays ?? [])
    }

    private var weekStrip: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "This week")
            HStack(spacing: 6) {
                ForEach(days, id: \.index) { day in
                    VStack(spacing: 9) {
                        Circle()
                            .fill(day.trained ? Color.done : .clear)
                            .frame(width: 40, height: 40)
                            .overlay(Circle().strokeBorder(edge(day), lineWidth: 2))
                        Text(day.initial)
                            .font(.captionText)
                            .foregroundStyle(day.isToday ? .fg : .dim)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(strippedForVoice)
        }
    }

    /// Trained is filled. Today is ringed. A planned day still to come is
    /// outlined. A planned day already gone looks like any other empty day,
    /// on purpose: absence, not failure.
    private func edge(_ day: StripDay) -> Color {
        if day.trained { return .done }
        if day.isToday { return .brandCyan }
        return day.planned && day.upcoming ? .lineStrong : .raise
    }

    private var strippedForVoice: String {
        let trained = days.filter(\.trained).count
        return "\(amount(trained, "session")) logged this week."
    }

    // MARK: - today's lifts, or the offer to build a week

    @ViewBuilder private var todaysLifts: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Today's lifts")

            if shape == .firstWorkout {
                Button { buildingWeek = true } label: {
                    VStack(spacing: 6) {
                        // no bull here: he is in the reason card already, and
                        // two of him read as clutter
                        Text("Nothing here yet")
                            .font(.head)
                            .foregroundStyle(.fg)
                        Text("Say which days you can train and what each one is.")
                            .font(.bodyText)
                            .foregroundStyle(.dim)
                            .multilineTextAlignment(.center)
                        Text("Build your week →")
                            .font(.bodyText)
                            .foregroundStyle(.brandCyan)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(18)
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.lineStrong))
                    .contentShape(.rect(cornerRadius: 18))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("build-your-week")
            } else {
                Card {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array((session?.exercises ?? store.plannedToday).enumerated()),
                                id: \.element.exerciseId) { index, exercise in
                            HStack {
                                Text(exercise.name)
                                    .font(.head)
                                    .foregroundStyle(.fg)
                                Spacer()
                                Text(exercise.planLine)
                                    .font(.bodyText)
                                    .foregroundStyle(.dim)
                                    .monospacedDigit()
                            }
                            .padding(.top, index == 0 ? 0 : 10)
                        }
                    }
                }
            }
        }
    }

    private var unfinishedCard: some View {
        Group {
            // a workout left open yesterday. the whole card is the button
            if session == nil, let unfinished = store.unfinished {
                Button {
                    store.resume(unfinished)
                    logging = true
                } label: {
                    Card {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                SectionLabel(text: "Unfinished")
                                Text(unfinished.label).font(.head).foregroundStyle(.fg)
                                Text("Resume from \(unfinished.startedAt.formatted(.relative(presentation: .named)))")
                                    .font(.bodyText)
                                    .foregroundStyle(.brandCyan)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.dim)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 20)
            }
        }
    }
}

// "1 lift", "2 lifts"
private func amount(_ count: Int, _ word: String) -> String {
    "\(count) \(word)\(count == 1 ? "" : "s")"
}

#Preview {
    TodayView()
        .environment(SessionStore())
        .environment(ProfileStore(defaults: UserDefaults(suiteName: "preview")!))
}
