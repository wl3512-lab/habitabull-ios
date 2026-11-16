//
// one goal: a lift, a number, a date.
//
// The web app has had this since the first week and the phone has not, which
// is most of why the home screen read as a screen with nothing on it. A plan
// says what to do today. A goal says what today is for.
//
// Three decisions and no more. Which lift, how heavy, by when: anything else
// on this screen is another chance to put the whole thing off.

import SwiftUI
import HabitaBullKit

struct GoalScreen: View {
    @Environment(SessionStore.self) private var store
    @Environment(ProfileStore.self) private var profiles
    @Environment(\.dismiss) private var dismiss

    /// Which lift, if she has picked one yet.
    @State private var lift: String?
    @State private var weight = 0.0
    /// The day she is aiming at, as the same "2026-12-10" the sessions use.
    @State private var targetDate = ""
    @State private var picking = false
    @State private var filled = false

    private var history: [TrainingSession] { store.sessions.map(\.asTrainingSession) }
    private var existing: Goal? { profiles.profile?.goal }

    /// The weight she is actually at, from finished sets only.
    private var best: Double { lift.map { Goals.best(history, $0) } ?? 0 }
    private var step: Double { lift.flatMap { ExerciseLibrary.find($0)?.increment } ?? 5 }

    private var ready: Bool { lift != nil && weight > 0 && !targetDate.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("What are you working towards?")
                    .font(.figure)
                    .foregroundStyle(.fg)

                Text("One lift, one number. You can change it whenever you want.")
                    .font(.bodyText)
                    .foregroundStyle(.dim)
                    .padding(.top, 6)

                liftRow.padding(.top, 26)

                if lift != nil {
                    NumberStepper(label: "Target weight", value: $weight, step: step,
                                  minimum: step, unit: "lb", halves: true)
                        .padding(.top, 16)

                    standing.padding(.top, 12)

                    byWhen.padding(.top, 26)

                    Pill(title: existing == nil ? "Set this goal" : "Save changes") { save() }
                        .padding(.top, 30)
                        .disabled(!ready)
                        .accessibilityIdentifier("goal-save")
                }

                if existing != nil {
                    Pill(title: "Remove goal", variant: .ghost) {
                        profiles.update { $0.goal = nil }
                        dismiss()
                    }
                    .padding(.top, 12)
                    .accessibilityIdentifier("goal-remove")
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.ground)
        .navigationTitle("Your goal")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $picking) {
            // no sets step: how many sets of it she does is not part of a goal
            AddLiftView(excluding: notForGoals, picksSets: false) { id, _ in
                choose(id)
            }
        }
        .onAppear(perform: fill)
    }

    // MARK: - which lift

    /// Bodyweight and held lifts are kept out of the picker: a goal measured
    /// in pounds needs a lift that is loaded in pounds, and "200 lb plank" is
    /// not a sentence.
    ///
    /// So are the assisted machines. Their number is help, so every part of a
    /// goal runs backwards on one: the suggestion offered her more help as
    /// something to aim for, and a real target of 40 lb of help after logging
    /// 45 counted as already met, because met is `>=`.
    private var notForGoals: [String] {
        let allowed = Set(ExerciseLibrary.forGoals.map(\.id))
        return ExerciseLibrary.liftable.map(\.id).filter { !allowed.contains($0) }
    }

    private var liftRow: some View {
        Button { picking = true } label: {
            Card {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionLabel(text: "The lift")
                        Text(lift.map(name) ?? "Pick a lift")
                            .font(.head)
                            .foregroundStyle(lift == nil ? .brandCyan : .fg)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.dim)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("goal-lift")
    }

    /// Where she is now, said plainly. Without it the number above is a wish
    /// with nothing to measure it against.
    private var standing: some View {
        Text(best > 0
             ? "Your best so far is \(best.formatted()) lb."
             : "Nothing logged for this lift yet, so this starts from zero.")
            .font(.bodyText)
            .foregroundStyle(.dim)
    }

    // MARK: - by when

    private var byWhen: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "By when")
            HStack(spacing: 10) {
                ForEach([4, 8, 12], id: \.self) { weeks in
                    chip(weeks)
                }
            }
            Text(dateLine)
                .font(.bodyText)
                .foregroundStyle(.dim)
        }
    }

    private func chip(_ weeks: Int) -> some View {
        let picked = targetDate == day(inWeeks: weeks)
        return Button { targetDate = day(inWeeks: weeks) } label: {
            Text("\(weeks) weeks")
                .font(.head)
                .foregroundStyle(picked ? .ground : .fg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(picked ? Color.brandCyan : .raise, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("goal-weeks-\(weeks)")
        .accessibilityAddTraits(picked ? [.isSelected] : [])
    }

    /// Reads the saved date back rather than a count of weeks, because the
    /// date is what is stored and a goal kept from last month should show the
    /// day she picked, not the nearest chip to it.
    private var dateLine: String {
        guard let date = Attendance.date(targetDate, Attendance.calendar()) else {
            return "Pick how long you are giving it."
        }
        let said = date.formatted(.dateTime.weekday(.wide).month().day())
        guard let left = Goals.daysLeft(Goal(exerciseId: lift ?? "", targetWeight: weight,
                                             targetDate: targetDate)) else { return said }
        if left < 0 { return "\(said), which has already passed." }
        if left == 0 { return "\(said), which is today." }
        return "\(said), \(left) \(left == 1 ? "day" : "days") from now."
    }

    // MARK: - the three pieces, filled and saved

    private func fill() {
        guard !filled else { return }
        filled = true
        guard let existing else {
            targetDate = day(inWeeks: 8)
            return
        }
        lift = existing.exerciseId
        weight = existing.targetWeight
        targetDate = existing.targetDate
    }

    private func choose(_ id: String) {
        lift = id
        weight = suggested(id)
    }

    /// An opening number she has a reason to believe: about a tenth heavier
    /// than her best, rounded onto plates she owns. Not a round 200, which is
    /// how a goal becomes decoration.
    private func suggested(_ id: String) -> Double {
        let step = ExerciseLibrary.find(id)?.increment ?? 5
        let now = Goals.best(history, id)
        let from = now > 0 ? now : store.nextTarget(of: id).weight
        let jump = max(step, (from * 0.1 / step).rounded() * step)
        return from + jump
    }

    private func save() {
        guard let lift, ready else { return }
        // changing the target of a goal she already has keeps the weight she
        // started it at. changing the lift is a new goal, so it starts again
        // from what she is lifting now.
        let from = existing?.exerciseId == lift ? (existing?.startWeight ?? best) : best
        let goal = Goal(exerciseId: lift, targetWeight: weight, targetDate: targetDate,
                        startWeight: from)
        profiles.update { $0.goal = goal }
        dismiss()
    }

    private func day(inWeeks weeks: Int) -> String {
        let cal = Attendance.calendar()
        let then = cal.date(byAdding: .day, value: weeks * 7, to: .now) ?? .now
        return Attendance.day(then, cal)
    }

    private func name(_ id: String) -> String {
        ExerciseLibrary.find(id)?.name ?? LoggedExercise(exerciseId: id, sets: []).name
    }
}

#Preview {
    NavigationStack { GoalScreen() }
        .environment(SessionStore())
        .environment(ProfileStore(defaults: UserDefaults(suiteName: "preview")!))
}

// MARK: - the goal where it is read rather than set

/// A line, a number, a thin bar. The same piece on Today and on Progress,
/// because a goal that reads one way in one place and another way in the
/// other is two goals as far as anyone looking at it is concerned.
struct GoalRow: View {
    let goal: Goal
    let history: [TrainingSession]
    var onTap: (() -> Void)? = nil

    private var share: Int { Goals.progress(history, goal) }
    private var met: Bool { Goals.met(history, goal) }
    private var name: String {
        ExerciseLibrary.find(goal.exerciseId)?.name
            ?? LoggedExercise(exerciseId: goal.exerciseId, sets: []).name
    }

    /// How long is left, or that it is met, or that the day has gone past.
    /// Said rather than hidden: a date that quietly disappears teaches her
    /// the app is not keeping count either.
    private var deadline: String {
        if met { return "Done" }
        guard let left = Goals.daysLeft(goal) else { return "" }
        if left < 0 { return "\(-left) \(left == -1 ? "day" : "days") over" }
        if left == 0 { return "Today" }
        if left < 14 { return "\(left) days left" }
        return "\(left / 7) weeks left"
    }

    var body: some View {
        Button { onTap?() } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionLabel(text: "Your goal")
                    Spacer()
                    Text(deadline)
                        .font(.captionText)
                        .foregroundStyle(met ? .done : .dim)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text("\(name), \(goal.targetWeight.formatted()) lb")
                        .font(.head)
                        .foregroundStyle(.fg)
                    Spacer()
                    Text("\(share)%")
                        .font(.head)
                        .foregroundStyle(met ? .done : .brandCyan)
                        .monospacedDigit()
                }
                bar
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("goal-row")
        .accessibilityLabel("Goal: \(name) at \(goal.targetWeight.formatted()) pounds, \(share) percent of the way. \(deadline).")
        .accessibilityAddTraits(onTap == nil ? [] : [.isButton])
    }

    private var bar: some View {
        Capsule()
            .fill(.raise)
            .frame(height: 6)
            .overlay(alignment: .leading) {
                GeometryReader { space in
                    Capsule()
                        .fill(met ? Color.done : .brandCyan)
                        .frame(width: space.size.width * Double(share) / 100)
                }
            }
    }
}

/// What stands in for the goal before there is one. An offer, not a nag: it
/// is the quiet colour and it says what setting one gets her.
struct GoalOffer: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Set a goal")
                        .font(.head)
                        .foregroundStyle(.fg)
                    Text("One lift, one number, by a date you pick.")
                        .font(.bodyText)
                        .foregroundStyle(.dim)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.dim)
            }
            .padding(16)
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.lineStrong))
            .contentShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("set-a-goal")
    }
}
