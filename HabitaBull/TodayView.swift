//
// the home screen. it answers one question: what do i do right now?

import SwiftUI

struct TodayView: View {
    @Environment(SessionStore.self) private var store
    @State private var logging = false

    private var session: Session? { store.today }
    private var finished: Bool { session?.completedAt != nil }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                SectionLabel(text: Date.now.formatted(.dateTime.weekday(.wide).month().day()))

                Text(session?.label ?? "Leg day")
                    .font(.figure)
                    .foregroundStyle(.fg)

                if let session, finished {
                    Card {
                        VStack(spacing: 12) {
                            Bull(pose: .cheer, size: 112)
                            Text("\(amount(session.liftsDone, "lift")) done. See you next time.")
                                .font(.emphasis)
                                .foregroundStyle(.fg)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    Card {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionLabel(text: "Today's lifts")
                            ForEach(session?.exercises ?? starterExercises, id: \.exerciseId) { exercise in
                                HStack {
                                    Text(exercise.name)
                                        .font(.head)
                                        .foregroundStyle(.fg)
                                    Spacer()
                                    Text("\(exercise.sets.count) × \(exercise.sets.first?.reps ?? 0)")
                                        .font(.bodyText)
                                        .foregroundStyle(.dim)
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                }

                if store.saveFailed {
                    Text("This phone isn't saving right now.")
                        .font(.bodyText)
                        .foregroundStyle(.fault)
                }

                Spacer()

                if !finished {
                    Pill(title: session == nil ? "Start workout" : "Continue workout") {
                        store.startWorkout()
                        logging = true
                    }
                }

                #if DEBUG
                if session != nil {
                    Pill(title: "Start over", variant: .ghost) {
                        store.resetToday()
                    }
                }
                #endif
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(.ground)
            .navigationDestination(isPresented: $logging) {
                LogView()
            }
        }
        .tint(.brandCyan)
    }
}

// "1 lift", "2 lifts"
private func amount(_ count: Int, _ word: String) -> String {
    "\(count) \(word)\(count == 1 ? "" : "s")"
}

#Preview {
    TodayView().environment(SessionStore())
}
