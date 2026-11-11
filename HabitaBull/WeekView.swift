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

                Spacer(minLength: 40)

                Pill(title: "Save my week") {
                    profiles.update {
                        $0.trainingDays = chosen
                        $0.weekChosen = true
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
        }
    }
}

#Preview {
    NavigationStack { WeekView() }
        .environment(ProfileStore(defaults: UserDefaults(suiteName: "preview")!))
}
