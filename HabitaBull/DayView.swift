//
// one day, read back.
//
// Reached from a day on the month grid and from "Last time" on the home
// screen. It is a receipt and nothing else: no editing, no orange, nothing
// that asks her to do anything about a day that is already over.
//
// A day can hold more than one workout, because a quick session in the
// morning and the plan in the evening are two things that happened and not
// one thing with the numbers added together.

import SwiftUI
import HabitaBullKit

struct DayView: View {
    /// The stored day, "2026-11-09".
    let day: String

    @Environment(SessionStore.self) private var store

    private var sessions: [Session] {
        store.sessions.filter { $0.date == day }.sorted { $0.startedAt < $1.startedAt }
    }

    private var said: String {
        guard let date = Attendance.date(day, Attendance.calendar()) else { return day }
        return date.formatted(.dateTime.weekday(.wide).month().day())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel(text: "That day")

                Text(said)
                    .font(.figure)
                    .foregroundStyle(.fg)
                    .padding(.top, 10)
                    // so a test can ask which day it opened on. A tap near
                    // the edge of one calendar day can land on the next, and
                    // "some day screen opened" cannot tell the two apart.
                    .accessibilityIdentifier("day-detail-date")

                if sessions.isEmpty {
                    Text("Nothing logged on this day.")
                        .font(.emphasis)
                        .foregroundStyle(.dim)
                        .padding(.top, 10)
                } else {
                    ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                        card(session).padding(.top, index == 0 ? 24 : 18)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.ground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("day-detail")
    }

    private func card(_ session: Session) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(session.label)
                        .font(.head)
                        .foregroundStyle(.fg)
                    Spacer()
                    Text(when(session))
                        .font(.captionText)
                        .foregroundStyle(.dim)
                }

                ForEach(Array(session.exercises.enumerated()), id: \.element.exerciseId) { index, lift in
                    HStack(alignment: .firstTextBaseline) {
                        Text(lift.name)
                            .font(.bodyText)
                            .foregroundStyle(.fg)
                        Spacer()
                        Text(done(lift))
                            .font(.bodyText)
                            .foregroundStyle(.dim)
                            .monospacedDigit()
                    }
                    .padding(.top, index == 0 ? 16 : 10)
                }

                if session.exercises.isEmpty {
                    Text("Opened and left empty.")
                        .font(.bodyText)
                        .foregroundStyle(.dim)
                        .padding(.top, 12)
                }
            }
        }
    }

    /// When it was, and how long it took when the app knows: a workout left
    /// open has no end to measure to, and saying so is better than pretending
    /// it lasted until she closed the app.
    private func when(_ session: Session) -> String {
        let started = session.startedAt.formatted(date: .omitted, time: .shortened)
        guard let finished = session.completedAt else { return "\(started), left open" }
        let minutes = Int(finished.timeIntervalSince(session.startedAt) / 60)
        guard minutes >= 1 else { return started }
        return "\(started) · \(minutes) min"
    }

    /// What she actually did of that lift. Sets she did not finish are not
    /// counted, and her best finished set is the one worth printing: the
    /// heaviest, or on a machine that counts help, the one she needed the
    /// least help on. It used to be the plain heaviest, which on an assisted
    /// pull-up printed the set she had struggled most on.
    /// Found by a codex audit 2026-11-16.
    private func done(_ lift: LoggedExercise) -> String {
        let sets = lift.sets.filter(\.done)
        guard !sets.isEmpty else { return "not done" }
        let count = "\(sets.count) set\(sets.count == 1 ? "" : "s")"
        guard lift.usesWeight, let best = lift.best(of: sets) else {
            return "\(count) · \(sets.map { "\($0.reps)" }.joined(separator: ", ")) \(lift.unit)"
        }
        return "\(count) · \(lift.describe(best))"
    }
}

#Preview {
    NavigationStack { DayView(day: "2026-11-09") }
        .environment(SessionStore())
}
