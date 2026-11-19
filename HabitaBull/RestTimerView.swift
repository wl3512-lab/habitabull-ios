//
// rest between sets. same rule as the web version (components/RestTimer.tsx):
// it tells you when the rest it suggested is over, buzzes once, and never
// moves on by itself. you decide when you're ready

import SwiftUI
import UserNotifications

struct RestTimerView: View {
    // saved like in week 05 BasicNav, so your rest length sticks between workouts
    @AppStorage("restSeconds") private var restSeconds = 90

    // starts by itself after a logged set, and hands back when you're ready
    var startsRunning = false
    var exerciseIndex: Int? = nil
    var resumeUntil: Date? = nil    // picks up a rest from before the app closed
    var onFinished: (() -> Void)? = nil

    @Environment(SessionStore.self) private var store

    // the workout she is in, the same one LogView is showing. `today` goes
    // nil at midnight on a workout still in progress, which took the next-up
    // card and the set controls off this screen and left the Lock Screen
    // saying "Next set" with the real lift one tap away
    private var session: Session? { store.openSession ?? store.today }

    // the lift you just did, if this rest came after a logged set
    private var upcomingLift: Int? {
        guard let session else { return nil }
        if let exerciseIndex, session.exercises.indices.contains(exerciseIndex),
           session.exercises[exerciseIndex].setsLeft > 0 {
            return exerciseIndex
        }
        return session.nextSet?.exercise
    }

    private var lift: LoggedExercise? {
        guard let exerciseIndex, let exercises = session?.exercises,
              exercises.indices.contains(exerciseIndex) else { return nil }
        return exercises[exerciseIndex]
    }

    // a finish time, not a number counting down: the phone pauses timers when
    // the screen locks, but the finish time is still right when you come back
    @State private var endsAt: Date? = nil
    @State private var left = 0

    private let tick = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    private var resting: Bool { endsAt != nil }
    private var done: Bool { resting && left == 0 }

    private var progress: Double {
        guard resting, restSeconds > 0 else { return 0 }
        return 1 - Double(left) / Double(restSeconds)
    }

    var body: some View {
        // The screen is as tall as the phone and no taller, which was fine
        // until the set controls underneath needed two lines at the largest
        // accessibility sizes. The Spacer went to zero, there was nowhere
        // else for the overflow to go, and "- Set  + Set" was drawn under
        // the Done resting button.
        //
        // So: the same column, inside a scroll view that is at least a
        // screen tall. At ordinary sizes the content is shorter than that
        // minimum, the Spacer still pushes the button to the bottom and
        // nothing moves or scrolls. Past that it scrolls, and the button
        // goes with it rather than sitting on top of the controls.
        GeometryReader { screen in
            ScrollView {
                column(in: screen.size)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(.ground)
        .onReceive(tick) { _ in
            guard let endsAt else { return }
            left = max(0, Int(endsAt.timeIntervalSinceNow.rounded(.up)))
        }
        // one buzz, only on the change to done
        .sensoryFeedback(.success, trigger: done) { _, isDone in isDone }
        .onAppear {
            if let resumeUntil {
                endsAt = resumeUntil
                let remaining = max(0, Int(resumeUntil.timeIntervalSinceNow.rounded(.up)))
                left = remaining
                // the countdown came back, so what fires for it has to come
                // back too. The alert and the Lock Screen activity belong to
                // the process that started the rest, and both died with it:
                // the ring kept counting and nothing told her it had ended.
                // The alert's id is a constant, so this replaces rather than
                // doubles. Found by a codex audit 2026-11-18.
                if remaining > 0 {
                    RestAlert.schedule(in: remaining)
                    RestActivityController.start(endsAt: resumeUntil, nextUp: nextUpLine)
                }
            } else if startsRunning && !resting {
                start()
            }
        }
        .onChange(of: done) { _, isDone in
            if isDone {
                RestActivityController.markReady()
                Chime.play()
            }
        }
    }

    /// The screen's one column, measured against the space it was given.
    private func column(in screen: CGSize) -> some View {
        VStack(spacing: 24) {
            Text(done ? "Ready when you are" : resting ? "Resting" : "Rest")
                .font(.head)
                .foregroundStyle(.dim)

            ZStack {
                Circle()
                    .stroke(.raise, lineWidth: 16)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(done ? .done : .brandCyan, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(clock(resting ? left : restSeconds))
                    .font(.hero)
                    .monospacedDigit()
                    .foregroundStyle(.fg)
            }
            .frame(width: 220, height: 220)
            .padding(.top, 8)

            // during the rest as well as before it. every way into this screen
            // in the real app either starts the timer or restores a running
            // one, so hiding these while resting left no way at all to change
            // the rest length after the first run: whatever onboarding set was
            // what she was stuck with. hidden only at 0:00, where there is no
            // rest left to lengthen.
            if !done {
                HStack(spacing: 40) {
                    Button("−15s") { adjust(by: -15) }
                    Button("+15s") { adjust(by: 15) }
                }
                .font(.head)
                .foregroundStyle(.brandCyan)
            }

            nextUp

            Spacer()

            setControls

            // big button at the bottom, where your thumb already is
            Pill(title: resting ? "Done resting" : "Start rest") {
                resting ? stop() : start()
            }
        }
        .padding(24)
        // at least a screenful, so the Spacer above still has something to
        // push against and the ordinary layout is the one it always was
        .frame(minWidth: screen.width, minHeight: screen.height)
    }

    // the words on the Lock Screen
    private var nextUpLine: String {
        guard let upcomingLift, let upcoming = session?.exercises[upcomingLift],
              let set = upcoming.sets.first(where: { !$0.done }) else { return "Next set" }
        return "\(upcoming.name), \(upcoming.describe(set))"
    }

    // what's coming, so you can load the bar while you rest. the weight can
    // change right here, where you find out it was wrong
    @ViewBuilder private var nextUp: some View {
        if let upcomingLift, let upcoming = session?.exercises[upcomingLift],
           let set = upcoming.sets.first(where: { !$0.done }) {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Next up")
                    Text(upcoming.name).font(.head).foregroundStyle(.fg)
                    if upcoming.usesWeight {
                        HStack {
                            weightButton("minus", name: "Take \(upcoming.weightStep.formatted()) pounds off \(upcoming.name)", disabled: set.weight <= 0) {
                                store.setUpcomingWeight(onExercise: upcomingLift, to: set.weight - upcoming.weightStep)
                                // the lock screen is showing this same set
                                RestActivityController.update(nextUp: nextUpLine)
                            }
                            Spacer()
                            Text("\(set.weight.formatted()) lb × \(set.reps)")
                                .font(.titleText)
                                .foregroundStyle(.brandCyan)
                                .monospacedDigit()
                            Spacer()
                            weightButton("plus", name: "Put \(upcoming.weightStep.formatted()) more pounds on \(upcoming.name)", disabled: false) {
                                store.setUpcomingWeight(onExercise: upcomingLift, to: set.weight + upcoming.weightStep)
                                RestActivityController.update(nextUp: nextUpLine)
                            }
                        }
                    } else {
                        Text("\(set.reps) \(upcoming.unit)")
                            .font(.titleText)
                            .foregroundStyle(.brandCyan)
                    }
                }
            }
        }
    }

    private func weightButton(_ symbol: String, name: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.headline)
                .frame(width: 44, height: 44)
                .foregroundStyle(.fg)
                .background(.raise, in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .accessibilityLabel(name)
    }

    // with sets left, change the count. with none left, one tap for one more
    @ViewBuilder private var setControls: some View {
        if let lift, let exerciseIndex {
            if lift.setsLeft > 0 {
                SetCountRow(
                    setsLeft: lift.setsLeft,
                    canDrop: lift.canDropSet,
                    onDrop: {
                        store.dropSet(fromExercise: exerciseIndex)
                        RestActivityController.update(nextUp: nextUpLine)
                    },
                    onAdd: {
                        store.addSet(toExercise: exerciseIndex)
                        RestActivityController.update(nextUp: nextUpLine)
                    }
                )
            } else {
                // one more set changes what is next, and the Lock Screen was
                // left naming the lift she had already moved on from
                Button("One more set of \(lift.name)") {
                    store.addSet(toExercise: exerciseIndex)
                    RestActivityController.update(nextUp: nextUpLine)
                }
                .font(.head)
                .foregroundStyle(.brandCyan)
                .frame(minHeight: 44)
            }
        }
    }

    /// Fifteen seconds on or off. Before a rest it sets the one about to
    /// start. During a rest it moves the rest she is standing in too, because
    /// the moment you find out ninety seconds is not enough is the moment you
    /// are standing in it. Both change the saved length: the rest she just
    /// decided she needed is the rest she gets next set.
    private func adjust(by seconds: Int) {
        let next = min(600, max(15, restSeconds + seconds))
        guard next != restSeconds else { return }
        let moved = next - restSeconds
        restSeconds = next

        guard resting, let current = endsAt else { return }
        let when = max(.now, current.addingTimeInterval(TimeInterval(moved)))
        endsAt = when
        left = max(0, Int(when.timeIntervalSinceNow.rounded(.up)))
        if left > 0 {
            RestAlert.schedule(in: left)
        } else {
            // no trigger can be scheduled for zero seconds, and there is
            // nothing left to be alerted about. Through the owner, not
            // straight to the centre: removing the request by hand left the
            // ask for the rest she just shortened still queued, and it went
            // on to post an alert for a finish time that no longer existed.
            RestAlert.cancel()
        }
        store.setRest(endsAt: when, lift: exerciseIndex)
        RestActivityController.start(endsAt: when, nextUp: nextUpLine)
    }

    private func start() {
        endsAt = Date.now.addingTimeInterval(TimeInterval(restSeconds))
        left = restSeconds
        RestAlert.schedule(in: restSeconds)
        if let endsAt {
            store.setRest(endsAt: endsAt, lift: exerciseIndex)
            RestActivityController.start(endsAt: endsAt, nextUp: nextUpLine)
        }
    }

    private func stop() {
        endsAt = nil
        RestAlert.cancel()
        RestActivityController.stop()
        store.clearRest()
        onFinished?()
    }

    private func clock(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
}

// the part the web app can't do: an alert that still shows up with the phone
// locked. if the app is open when rest ends, iOS skips the banner and the
// screen + buzz do the job instead
@MainActor
enum RestAlert {
    /// The one ask-and-add in flight, so that ending a rest can call it off.
    ///
    /// `removePendingNotificationRequests` only removes what has already been
    /// added, and the add here happens after an await on the permission
    /// answer. So a rest she ended while that answer was outstanding could
    /// still post its alert afterwards, and an older adjustment could still
    /// overwrite a newer request under the same "rest" id. Found by a codex
    /// audit 2026-11-17. The timing cannot be made to happen on a phone to
    /// order, so the three calls into iOS below are closures and the ordering
    /// is tested by holding one of them open: see RestAlertTests.
    private static var pending: Task<Void, Never>?

    /// Which rest the queued ask belongs to.
    ///
    /// Cancelling a Swift task is a request, not a retraction. The add is an
    /// await of its own, so a rest she ended while it was in flight still
    /// posted its alert: the removal ran before there was anything to remove.
    /// Every rest gets a number, and the ask looks again once its add has
    /// landed. If the number has moved on, it takes the alert back.
    /// Found by a codex audit 2026-11-17.
    private static var now = 0

    /// Whether `mine` is still the rest she is in.
    static func current(_ mine: Int) -> Bool { mine == now }

    /// The three things this wants from iOS, held as closures so the ordering
    /// above can be tested without a phone and without ever posting a real
    /// notification. The app never sets them; only the tests do.
    static var ask: @MainActor () async -> Bool = {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }
    static var post: @MainActor (UNNotificationRequest) async -> Void = { request in
        _ = try? await UNUserNotificationCenter.current().add(request)
    }
    static var drop: @MainActor () -> Void = {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["rest"])
    }

    /// Called off, and anything already queued with it.
    static func cancel() {
        now += 1
        pending?.cancel()
        // the handle is kept, not cleared. A cancelled ask still has its last
        // word to say about the "rest" id once the add it was inside comes
        // back, and the next rest has to queue behind that. Clearing it here
        // broke the chain, and the stale clean-up could then land after the
        // new alert and take it away.
        drop()
    }

    static func schedule(in seconds: Int) {
        // a new rest replaces the old one, the ask included
        now += 1
        // and waits for it to finish before touching the centre. Two asks in
        // flight at once cannot be put in order: they add and remove under one
        // "rest" id, so the one that happened to come back last won, and the
        // stale one's tidying up could take the live alert with it. One at a
        // time, newest last, and whoever is no longer current cleans up after
        // itself before the next one begins.
        // and the alert already standing comes down now, not when the new one
        // is ready. Bumping the number stops the old ask from posting, but it
        // does nothing about a request that has already been posted: press
        // +15s near the end of a rest and the old alert was still live until
        // the new one replaced it, so a slow permission answer, or a denied
        // one, left the phone going off fifteen seconds early.
        // Found by a codex audit 2026-11-17.
        drop()
        let queued = pending
        pending?.cancel()
        pending = alert(in: seconds, rest: now, after: queued)
    }

    /// Waits for the queued ask to finish. Tests only: nothing in the app has
    /// anything to wait for.
    static func settle() async { await pending?.value }
}

@MainActor
private func alert(in seconds: Int, rest mine: Int, after queued: Task<Void, Never>?) -> Task<Void, Never> {
    let content = UNMutableNotificationContent()
    content.title = "Ready when you are"
    content.body = "Rest's over. Next set whenever you are."
    content.sound = UNNotificationSound(named: UNNotificationSoundName("chime.wav"))
    // when this rest is actually over, fixed now. the interval used to be
    // measured from whenever the permission answer came back, so saying yes
    // twenty seconds into a ninety second rest moved the alert twenty seconds
    // past the end of it.
    let endsAt = Date.now.addingTimeInterval(TimeInterval(seconds))
    return Task {
        // the rest before this one finishes first, cancelled or not, so that
        // its last word about the "rest" id is said before ours
        await queued?.value
        // ask first, and add only once the answer is in. this used to submit
        // the alert while the permission sheet was still on screen, so the one
        // rest most likely to go off silently was the very first one on a new
        // phone, which is the rest she would judge the app on.
        // iOS only shows the popup once; after that this returns the answer.
        let allowed = await RestAlert.ask()
        guard allowed, !Task.isCancelled, RestAlert.current(mine) else { return }
        // a rest that ended while she was reading the permission sheet needs
        // no alert: she is already looking at the phone
        let left = endsAt.timeIntervalSinceNow
        guard left > 0.5 else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: left, repeats: false)
        // same id every time, so starting a new rest replaces the old alert
        let request = UNNotificationRequest(identifier: "rest", content: content, trigger: trigger)
        guard !Task.isCancelled, RestAlert.current(mine) else { return }
        await RestAlert.post(request)
        // and once more after it, because that was an await too. A rest she
        // ended inside it was cancelled against a request that did not exist
        // yet, so the alert outlived the rest. Taking it back here is the only
        // order that holds: it cannot be removed before it is there.
        if !RestAlert.current(mine) { RestAlert.drop() }
    }
}

#Preview {
    RestTimerView().environment(SessionStore())
}
