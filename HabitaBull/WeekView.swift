//
// the week, agreed rather than assigned.
//
// Offered from the home screen, never before a first session. Onboarding
// already placed three days so the app has an answer; this is where she takes
// them over. Opening on what was placed for her means the quickest honest
// answer is one tap on Save.

import SwiftUI
import HabitaBullKit

struct WeekView: View {
    @Environment(ProfileStore.self) private var profiles
    @Environment(\.dismiss) private var dismiss

    /// 0 = Sunday, matching the calendar, the strip and the rules package.
    @State private var days: Set<Int> = []
    @State private var started = false
    /// The workout on each of those days, which is the half of the week the
    /// circles never showed. Kept here while she is deciding so the list
    /// under them answers to the days above as she taps.
    @State private var routine = Routine()
    /// Whether the week on screen is hers yet: a routine she has saved before,
    /// or one she has opened a day of and changed. Until then it is the app's
    /// own suggestion, and a suggestion is allowed to be reconsidered when she
    /// changes how many days she is training.
    @State private var mine = false

    private let initials = ["S", "M", "T", "W", "T", "F", "S"]
    private let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    private var chosen: [Int] { days.sorted() }

    /// What the days she has picked actually say about her week.
    private var note: String {
        if days.isEmpty { return "Pick at least one day." }
        if days.count == 7 { return "Every day. Rest is part of the training too." }
        if Schedule.hasBackToBack(chosen) {
            return "\(days.count) days, two of them back to back. That is fine, it just asks more of your recovery."
        }
        return "\(days.count) days, spread out."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel(text: "Your week")

                Text("Which days can you keep?")
                    .font(.figure)
                    .foregroundStyle(.fg)
                    .padding(.top, 14)

                Text("Not the days you wish you could. The ones you can.")
                    .font(.emphasis)
                    .foregroundStyle(.dim)
                    .padding(.top, 4)

                HStack(spacing: 8) {
                    ForEach(0..<7, id: \.self) { index in
                        let on = days.contains(index)
                        Button {
                            if on { days.remove(index) } else { days.insert(index) }
                        } label: {
                            VStack(spacing: 9) {
                                Circle()
                                    .fill(on ? Color.brandCyan : .clear)
                                    .frame(width: 40, height: 40)
                                    .overlay(Circle().strokeBorder(on ? .brandCyan : .lineStrong,
                                                                   lineWidth: 2))
                                Text(initials[index])
                                    .font(.captionText)
                                    .foregroundStyle(on ? .fg : .dim)
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(names[index])
                        .accessibilityIdentifier("day-\(index)")
                        .accessibilityAddTraits(on ? [.isSelected] : [])
                    }
                }
                .padding(.top, 30)

                Text(note)
                    .font(.bodyText)
                    .foregroundStyle(.dim)
                    .padding(.top, 18)

                workouts.padding(.top, 34)

                Spacer(minLength: 40)

                Pill(title: "Save my week") {
                    profiles.update {
                        $0.trainingDays = chosen
                        $0.weekChosen = true
                        $0.routine = routine
                    }
                    dismiss()
                }
                .disabled(days.isEmpty)
                .opacity(days.isEmpty ? 0.5 : 1)
                .padding(.top, 20)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.ground)
        .navigationTitle("")
        .onAppear {
            // opening on what she already has, so Save is a real answer and
            // not a form to fill in. placed days are still days.
            guard !started else { return }
            started = true
            let placed = profiles.profile?.trainingDays ?? []
            days = Set(placed.isEmpty ? Schedule.placeDays(3) : placed)
            // the week she already agreed to is the draft from here on. read
            // once: after this the draft is the only copy, or a workout she
            // edits would be thrown away the moment she touches a day
            if let saved = profiles.profile?.routine {
                routine = saved
                mine = true
            }
            replan()
        }
        .onChange(of: days) { _, _ in replan() }
    }

    // MARK: - what each day actually is

    /// The days as workouts. This is the half of a week that matters and the
    /// screen used to leave out: seven circles said when she trains and
    /// nothing at all said what she would be doing.
    @ViewBuilder private var workouts: some View {
        if !routine.days.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "Your workouts")
                Card {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(routine.inOrder.enumerated()), id: \.element.weekday) { index, day in
                            NavigationLink {
                                RoutineDayView(label: day.label, routine: $routine, mine: $mine)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        SectionLabel(text: names[day.weekday])
                                        Text(day.label)
                                            .font(.head)
                                            .foregroundStyle(.fg)
                                    }
                                    Spacer()
                                    Text(count(day.label))
                                        .font(.bodyText)
                                        .foregroundStyle(.dim)
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.dim)
                                        .padding(.leading, 8)
                                }
                                .contentShape(.rect)
                                .padding(.top, index == 0 ? 0 : 16)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("workout-\(day.weekday)")
                        }
                    }
                }
                Text("Two days with the same name are the same workout. Editing one edits both.")
                    .font(.captionText)
                    .foregroundStyle(.dim)

                // said once, plainly, and never in the way of saving: the
                // guidance asks for every group twice a week, and push, pull
                // and legs on three days trains each of them once. Hers to
                // decide, which is why it is a line and not a warning
                if !DayTypes.coversTwiceWeekly(kinds) {
                    Text("On this split some muscle groups only get trained once a week. Twice is what the guidance asks for.")
                        .font(.captionText)
                        .foregroundStyle(.dim)
                }
            }
        }
    }

    /// The kind of day each workout on the week is, in order.
    private var kinds: [String] {
        routine.inOrder.map { routine.type(of: $0.label) }
    }

    private func count(_ label: String) -> String {
        let lifts = routine.library[label]?.count ?? 0
        return "\(lifts) lift\(lifts == 1 ? "" : "s")"
    }

    /// Re-read the plan whenever the days change, keeping every name and
    /// every lift she has already decided on, and only those: until she has
    /// saved a week or opened one of its days, what is on screen is the app
    /// talking to itself.
    private func replan() {
        let before = routine
        // every weekday she has named, on or off. this rides on the routine
        // rather than on the screen, so it is still here after she closes the
        // app: Monday, renamed to "Chest and arms", taken out of the week and
        // put back a day later came back as the app's default Push day
        var remembered = before.remembered
        for day in before.days { remembered[day.weekday] = day.label }

        // hers is kept, the app's own guess is made again. a suggested week of
        // push, pull and legs cut down to one day should become a full body
        // day, not a push day she never asked for
        var next = Planner.plan(for: chosen, keeping: mine ? before : nil)
        next.remembered = remembered

        // and a day coming back gets what she put on it, not a fresh guess.
        // only for a week that is hers: the app's own suggestion is allowed to
        // be reconsidered, which is the whole point of the line above.
        if mine {
            next.days = next.days.map { day in
                guard before.label(on: day.weekday) == nil,
                      let named = remembered[day.weekday] else { return day }
                return Routine.Day(weekday: day.weekday, label: named)
            }
            for day in next.days where next.library[day.label] == nil {
                next.library[day.label] = Planner.lifts(for: day.label)
            }
        }
        routine = next
    }
}

#Preview {
    NavigationStack { WeekView() }
        .environment(ProfileStore(defaults: UserDefaults(suiteName: "preview")!))
}
