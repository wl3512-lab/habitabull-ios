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
    var onFinished: (() -> Void)? = nil

    @Environment(SessionStore.self) private var store

    // the lift you just did, if this rest came after a logged set
    private var upcomingLift: Int? {
        guard let session = store.today else { return nil }
        if let exerciseIndex, session.exercises.indices.contains(exerciseIndex),
           session.exercises[exerciseIndex].setsLeft > 0 {
            return exerciseIndex
        }
        return session.nextSet?.exercise
    }

    private var lift: LoggedExercise? {
        guard let exerciseIndex, let exercises = store.today?.exercises,
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

            if !resting {
                HStack(spacing: 40) {
                    Button("−15s") { restSeconds = max(15, restSeconds - 15) }
                    Button("+15s") { restSeconds = min(600, restSeconds + 15) }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ground)
        .onReceive(tick) { _ in
            guard let endsAt else { return }
            left = max(0, Int(endsAt.timeIntervalSinceNow.rounded(.up)))
        }
        // one buzz, only on the change to done
        .sensoryFeedback(.success, trigger: done) { _, isDone in isDone }
        // iOS only shows the permission popup once, after that this just returns
        .task {
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        }
        .onAppear {
            if startsRunning && !resting { start() }
        }
        .onChange(of: done) { _, isDone in
            if isDone { RestActivityController.markReady() }
        }
    }

    // the words on the Lock Screen
    private var nextUpLine: String {
        guard let upcomingLift, let upcoming = store.today?.exercises[upcomingLift],
              let set = upcoming.sets.first(where: { !$0.done }) else { return "Next set" }
        let numbers = upcoming.usesWeight ? "\(set.weight.formatted()) lb × \(set.reps)" : "\(set.reps) reps"
        return "\(upcoming.name), \(numbers)"
    }

    // what's coming, so you can load the bar while you rest. the weight can
    // change right here, where you find out it was wrong
    @ViewBuilder private var nextUp: some View {
        if let upcomingLift, let upcoming = store.today?.exercises[upcomingLift],
           let set = upcoming.sets.first(where: { !$0.done }) {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Next up")
                    Text(upcoming.name).font(.head).foregroundStyle(.fg)
                    if upcoming.usesWeight {
                        HStack {
                            weightButton("minus", name: "Take \(upcoming.weightStep.formatted()) pounds off \(upcoming.name)", disabled: set.weight <= 0) {
                                store.setUpcomingWeight(onExercise: upcomingLift, to: set.weight - upcoming.weightStep)
                            }
                            Spacer()
                            Text("\(set.weight.formatted()) lb × \(set.reps)")
                                .font(.titleText)
                                .foregroundStyle(.brandCyan)
                                .monospacedDigit()
                            Spacer()
                            weightButton("plus", name: "Put \(upcoming.weightStep.formatted()) more pounds on \(upcoming.name)", disabled: false) {
                                store.setUpcomingWeight(onExercise: upcomingLift, to: set.weight + upcoming.weightStep)
                            }
                        }
                    } else {
                        Text("\(set.reps) reps")
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
                    onDrop: { store.dropSet(fromExercise: exerciseIndex) },
                    onAdd: { store.addSet(toExercise: exerciseIndex) }
                )
            } else {
                Button("One more set of \(lift.name)") {
                    store.addSet(toExercise: exerciseIndex)
                }
                .font(.head)
                .foregroundStyle(.brandCyan)
                .frame(minHeight: 44)
            }
        }
    }

    private func start() {
        endsAt = Date.now.addingTimeInterval(TimeInterval(restSeconds))
        left = restSeconds
        scheduleRestAlert(in: restSeconds)
        if let endsAt {
            RestActivityController.start(endsAt: endsAt, nextUp: nextUpLine)
        }
    }

    private func stop() {
        endsAt = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rest"])
        RestActivityController.stop()
        onFinished?()
    }

    private func clock(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
}

// the part the web app can't do: an alert that still shows up with the phone
// locked. if the app is open when rest ends, iOS skips the banner and the
// screen + buzz do the job instead
func scheduleRestAlert(in seconds: Int) {
    let content = UNMutableNotificationContent()
    content.title = "Ready when you are"
    content.body = "Rest's over. Next set whenever you are."
    content.sound = .default
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
    // same id every time, so starting a new rest replaces the old alert
    let request = UNNotificationRequest(identifier: "rest", content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request)
}

#Preview {
    RestTimerView().environment(SessionStore())
}
