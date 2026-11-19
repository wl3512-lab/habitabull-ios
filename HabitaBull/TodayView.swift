//
// the home screen. it answers one question: what do i do right now?
//
// Before she has agreed to a week the answer is "one session, no setup",
// which is the finding the whole screen is built on: people log a workout
// before they will set anything up. After that the answer is the day's plan,
// and then everything under it is evidence: the week she kept, the goal she
// set, what she did last time.
//
// The order is deliberate. The day and the one action are at the top, where
// the thumb is. The measuring is below them, because a screen that opens on
// how far along you are is a screen that asks you to feel something before it
// lets you do anything.
//
// Her reason is not here: it is on the launch screen, under whether today is
// a workout day or a rest day. The bull stayed, on the two screens where
// there is no plan to look at.

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
    @State private var settingGoal = false
    /// The day she has opened from the last time row.
    @State private var openDay: String?
    /// Today, as a value the screen can be told to re-read.
    ///
    /// `Date.now` is not observable, so a phone left on the counter overnight
    /// would still be offering yesterday's workout in the morning, or telling
    /// somebody to rest on a day she had planned to train.
    @State private var day = Date.now
    @Environment(\.scenePhase) private var phase

    init(place: Binding<Place> = .constant(.today)) { _place = place }

    private var session: Session? { store.today }
    private var finished: Bool { session?.completedAt != nil }
    private var shape: HomeShape {
        Home.shape(profile: profiles.profile, today: session, now: day)
    }

    private var firstRun: Bool { shape == .firstWorkout }

    /// The greeting on the day she signed up, or nothing. Her reason is not
    /// here any more: it is on the launch screen.
    private var aside: String? {
        TodayAside.line(for: profiles.profile, hasHistory: !store.sessions.isEmpty)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    dayLine

                    Text(Home.headline(shape))
                        .font(.figure)
                        .foregroundStyle(.fg)
                        .padding(.top, 10)

                    subtitle

                    unfinishedCard

                    // Three orders, because the three screens are answering
                    // different questions. With no week yet the bull is a
                    // welcome and the plan is an offer at the bottom. With a
                    // plan, what you are about to lift sits under its own
                    // name, where you look for it, and the proof follows. On
                    // a rest day there is nothing to list, so he gets the
                    // space the plan would have had.
                    if firstRun {
                        mascot.padding(.top, 24)
                        action.padding(.top, 24)
                        weekBlock.padding(.top, 34)
                        offerToBuildAWeek.padding(.top, 34)
                    } else {
                        if case .plan = shape {
                            workCard.padding(.top, 20)
                            quickInstead
                        } else {
                            mascot.padding(.top, 20)
                            action.padding(.top, 20)
                        }
                        weekBlock.padding(.top, 34)
                        goalBlock.padding(.top, 30)
                        lastTimeBlock.padding(.top, 30)
                            // clear of the raised circle in the bar below it
                            .padding(.bottom, 20)
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
            // midnight while the app is open, and every return to it
            .onReceive(NotificationCenter.default
                .publisher(for: .NSCalendarDayChanged)
                .receive(on: RunLoop.main)) { _ in day = .now }
            .onChange(of: phase) { _, now in if now == .active { day = .now } }
            // and midnight while she is looking at it, which coming back to
            // the app does not cover
            .onReceive(NotificationCenter.default
                .publisher(for: .NSCalendarDayChanged)
                .receive(on: RunLoop.main)) { _ in day = .now }
            .navigationDestination(isPresented: $logging) { LogView() }
            .navigationDestination(isPresented: $buildingWeek) { WeekView() }
            .navigationDestination(isPresented: $settingGoal) { GoalScreen() }
            .navigationDestination(item: $openDay) { DayView(day: $0) }
        }
        .tint(.brandCyan)
    }

    // MARK: - the day, named and numbered

    /// "Wednesday, Nov 11 · Week 5", and the way back to the week itself.
    ///
    /// The week number is counted from the day she signed up, not from the
    /// first of January: the only week one she cares about is hers.
    private var dayLine: some View {
        HStack(alignment: .firstTextBaseline) {
            SectionLabel(text: stamp)
            Spacer()
            if profiles.profile?.weekChosen == true {
                Button("Change") { buildingWeek = true }
                    .font(.captionText)
                    .foregroundStyle(.brandCyan)
                    .accessibilityIdentifier("change-week")
            }
        }
    }

    private var stamp: String {
        let date = day.formatted(.dateTime.weekday(.wide).month().day())
        guard let week = weekNumber else { return date }
        return "\(date) · Week \(week)"
    }

    private var weekNumber: Int? {
        guard let started = profiles.profile?.createdAt else { return nil }
        let cal = Attendance.calendar()
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: started),
                                      to: cal.startOfDay(for: day)).day ?? 0
        return max(0, days) / 7 + 1
    }

    /// What the day costs, or the line a rest day needs so that "Rest day"
    /// does not read as a scolding, or the greeting on her first day.
    @ViewBuilder private var subtitle: some View {
        if case .plan = shape {
            Text("\(amount(plan.count, "lift")) · \(amount(plannedSets, "set"))")
                .font(.emphasis)
                .foregroundStyle(.dim)
                .padding(.top, 4)
        } else if shape == .rest, let note = Launch.note(.rest) {
            Text(note)
                .font(.emphasis)
                .foregroundStyle(.dim)
                .padding(.top, 4)
        }

        if let aside {
            Text(aside)
                .font(.emphasis)
                .foregroundStyle(.brandCyan)
                .padding(.top, 4)
        }
    }

    /// On his own, with nothing to say. He is on the launch screen and in the
    /// finished card too, so he only appears here when neither of those is
    /// the screen in front of her.
    @ViewBuilder private var mascot: some View {
        if !finished {
            Bull(pose: shape == .rest ? .rest : .stand, size: 132)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
        }
    }

    // MARK: - the workout, and the one action inside it

    /// What today is, by her routine: the workout's name and what is in it.
    /// Nil before she has agreed to a week, and on a day she does not train.
    private var todayPlan: (label: String, lifts: [String])? {
        let weekday = Attendance.calendar().component(.weekday, from: day) - 1
        return Planner.today(profiles.profile?.routine, weekday: weekday)
    }

    private var plan: [LoggedExercise] {
        if let session { return session.exercises }
        // a phone that agreed to a week before routines existed has no
        // routine to read, and still has to show today something
        guard let lifts = todayPlan?.lifts else { return store.plannedToday }
        return lifts.map(store.planned)
    }
    private var plannedSets: Int { plan.reduce(0) { $0 + $1.sets.count } }

    /// One card: the lifts with the weight she will actually put on the bar,
    /// and the button that starts them, inside the same box.
    ///
    /// They used to be two blocks with a gap between them, which read as a
    /// list and then, separately, an unrelated orange button. The weights are
    /// the reason to put them together: this is the workout, and that is the
    /// button for this workout.
    private var workCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(plan.enumerated()), id: \.element.exerciseId) { index, lift in
                    HStack(alignment: .firstTextBaseline) {
                        Text(lift.name)
                            .font(.head)
                            .foregroundStyle(.fg)
                        Spacer()
                        Text(lift.planDetail)
                            .font(.bodyText)
                            .foregroundStyle(.dim)
                            .monospacedDigit()
                    }
                    .padding(.top, index == 0 ? 0 : 12)
                }

                Rectangle()
                    .fill(.raise)
                    .frame(height: 1)
                    .padding(.vertical, 18)

                Pill(title: session == nil ? "Start workout" : "Continue workout") {
                    store.startWorkout(label: todayPlan?.label ?? "Leg day",
                                       lifts: todayPlan?.lifts)
                    logging = true
                }
            }
        }
    }

    /// The other way in, kept quiet and out of the card: the plan is the
    /// offer, this is the exception to it.
    @ViewBuilder private var quickInstead: some View {
        if session == nil {
            Button("Quick workout instead") {
                store.startQuickWorkout()
                logging = true
            }
            .font(.bodyText)
            .foregroundStyle(.brandCyan)
            .frame(maxWidth: .infinity)
            .padding(.top, 14)
        }
    }

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

        case .rest:
            // not a locked door: a day she did not pick is still a day she
            // can lift on, it just does not get an orange button
            VStack(alignment: .leading, spacing: 12) {
                Pill(title: "Train anyway", variant: .ghost) {
                    store.startQuickWorkout()
                    logging = true
                }
                Text("Nothing is planned for today.")
                    .font(.bodyText)
                    .foregroundStyle(.dim)
            }

        case .plan:
            // the plan's button lives inside its card
            EmptyView()
        }
    }

    // MARK: - the week she has actually kept

    private var days: [StripDay] {
        store.weekStrip(trainingDays: profiles.profile?.trainingDays ?? [])
    }

    private var records: [SessionRecord] { store.sessions.map(\.asRecord) }
    private var today: String { Attendance.day(day, Attendance.calendar()) }
    private var runningWeeks: Int { Attendance.streakWeeks(records, today: today) }

    private var weekBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(text: "This week")
                Spacer()
                if runningWeeks > 0 {
                    Text("\(amount(runningWeeks, "week")) running")
                        .font(.captionText)
                        .foregroundStyle(.done)
                }
            }
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
            .accessibilityIdentifier("week-strip")
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

    /// The strip reads as one thing, and it has to say the thing it is for.
    ///
    /// The seven circles say which days she trained, which are still coming,
    /// and which one is today. The spoken version said only how many, so the
    /// one distinction the strip exists to make could be seen and not heard.
    /// Found by a codex audit 2026-11-18.
    private var strippedForVoice: String {
        let names = ["Sunday", "Monday", "Tuesday", "Wednesday",
                     "Thursday", "Friday", "Saturday"]
        func name(_ day: StripDay) -> String { names[min(max(day.index, 0), 6)] }

        let trained = days.filter(\.trained)
        var said = "\(amount(trained.count, "session")) logged this week."
        if !trained.isEmpty {
            said += " Trained \(trained.map(name).formatted(.list(type: .and)))."
        }
        let ahead = days.filter { $0.planned && $0.upcoming && !$0.trained }
        if !ahead.isEmpty {
            said += " Still to come: \(ahead.map(name).formatted(.list(type: .and)))."
        }
        if let today = days.first(where: \.isToday) {
            said += " Today is \(name(today))\(today.trained ? ", logged" : "")."
        }
        if runningWeeks > 0 { said += " \(amount(runningWeeks, "week")) running." }
        return said
    }

    // MARK: - the goal, and what she did last time

    /// Slim on purpose. The goal is why today matters, not what today is, so
    /// it gets one line, one number and a bar six points tall.
    @ViewBuilder private var goalBlock: some View {
        if let goal = profiles.profile?.goal {
            GoalRow(goal: goal, history: store.sessions.map(\.asTrainingSession)) {
                settingGoal = true
            }
        } else if !store.sessions.isEmpty {
            // not offered on day one: a goal set before a single logged set
            // is a number picked out of the air
            GoalOffer { settingGoal = true }
        }
    }

    /// The last day she trained, named. It is the shortest honest answer to
    /// "am I actually doing this", and it is the one thing the phone knew and
    /// never said.
    @ViewBuilder private var lastTimeBlock: some View {
        if let last = previous {
            Button { openDay = last.date } label: {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Last time · \(stamp(last.date))")
                    HStack(alignment: .firstTextBaseline) {
                        Text(last.label)
                            .font(.head)
                            .foregroundStyle(.fg)
                        Spacer()
                        if let best = bestSet(last) {
                            Text(best)
                                .font(.bodyText)
                                .foregroundStyle(.dim)
                                .monospacedDigit()
                        }
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.dim)
                            .padding(.leading, 8)
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("last-time")
        }
    }

    /// The most recent day before today that she actually trained on.
    private var previous: Session? {
        store.sessions
            .filter { $0.date < today && $0.asRecord.attended }
            .max { $0.date < $1.date }
    }

    private func stamp(_ stored: String) -> String {
        guard let date = Attendance.date(stored, Attendance.calendar()) else { return stored }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    /// The heaviest set she finished that day, said the way the log says it.
    /// Bodyweight and held lifts have no weight to be best at, so they are
    /// left out rather than reported as zero.
    ///
    /// So are the machines that count help. 95 lb of counterweight is not a
    /// heavier set than a 60 lb curl, but it is a bigger number, so ranking
    /// the two put "Assisted Pull-up 95 lb" on the home screen as the best
    /// thing she did that day, and among assisted sets it picked the one she
    /// had struggled most on. There is no honest way to rank help against
    /// load, so help does not enter.
    /// Found by a codex audit 2026-11-17.
    private func bestSet(_ session: Session) -> String? {
        var best: (lift: LoggedExercise, set: LoggedSet)?
        for lift in session.exercises where lift.usesWeight && !lift.assisted {
            // the same rule the day card and the chart use, so that three
            // screens reading one session cannot name three different sets.
            // Comparing weight alone kept whichever tie came first: 135 x 5
            // logged before 135 x 8 put "135 lb x 5" on the home screen and
            // "135 lb x 8" on the day it links to.
            // Found by a codex audit 2026-11-17.
            guard let top = lift.best(of: lift.sets.filter(\.done)) else { continue }
            if best == nil || Lifts.beats((top.weight, top.reps),
                                          (best!.set.weight, best!.set.reps),
                                          assisted: false) {
                best = (lift, top)
            }
        }
        guard let best else { return nil }
        return "\(best.lift.name) \(best.lift.describe(best.set))"
    }

    // MARK: - the offer to build a week

    private var offerToBuildAWeek: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Today's lifts")

            Button { buildingWeek = true } label: {
                VStack(spacing: 6) {
                    // no bull here: he is already at the top of this screen,
                    // and two of him read as clutter
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
                .accessibilityIdentifier("unfinished-card")
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
