//
// her profile: the three things the app knows about her.
//
// Her name, her reason and her week. Nothing else, because nothing else was
// asked for and a settings screen that invents fields is a screen that asks
// her to make decisions she never wanted to make. Every one of these is
// changeable here, which is the only reason this tab exists: the week was
// agreed to once and people's weeks change.

import SwiftUI
import HabitaBullKit

struct ProfileScreen: View {
    @Environment(ProfileStore.self) private var profiles
    @Binding var place: Place
    @State private var buildingWeek = false

    private let initials = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel(text: "You")

                    Text(profiles.profile?.name.isEmpty == false
                         ? (profiles.profile?.name ?? "") : "Your profile")
                        .font(.figure)
                        .foregroundStyle(.fg)
                        .padding(.top, 14)

                    ReasonCard(profile: profiles.profile, raised: false) { said in
                        profiles.update { $0.motivation = said }
                    }
                    .padding(.top, 26)

                    week.padding(.top, 34)

                    Text("Nothing here leaves the phone.")
                        .font(.captionText)
                        .foregroundStyle(.dim)
                        .padding(.top, 30)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.ground)
            .standingOn(.profile) { place = $0 }
            .navigationDestination(isPresented: $buildingWeek) { WeekView() }
        }
        .tint(.brandCyan)
    }

    private var days: [Int] { profiles.profile?.trainingDays ?? [] }

    private var week: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(text: "Your week")
                Spacer()
                Button("Change") { buildingWeek = true }
                    .font(.bodyText)
                    .foregroundStyle(.brandCyan)
                    .accessibilityIdentifier("change-week")
            }

            Card {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { index in
                            let on = days.contains(index)
                            VStack(spacing: 9) {
                                Circle()
                                    .fill(on ? Color.brandCyan : .clear)
                                    .frame(width: 34, height: 34)
                                    .overlay(Circle().strokeBorder(on ? .brandCyan : .lineStrong,
                                                                   lineWidth: 2))
                                Text(initials[index])
                                    .font(.captionText)
                                    .foregroundStyle(on ? .fg : .dim)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(spoken)

                    Text(note)
                        .font(.bodyText)
                        .foregroundStyle(.dim)
                }
            }
        }
    }

    /// What her week says, in the same words the week screen uses, so the two
    /// never disagree about what three days spread out means.
    private var note: String {
        if days.isEmpty { return "No days yet." }
        if profiles.profile?.weekChosen != true {
            return "Days we picked for you. Change them whenever you like."
        }
        if days.count == 7 { return "Every day. Rest is part of the training too." }
        if Schedule.hasBackToBack(days) {
            return "\(days.count) days, two of them back to back."
        }
        return "\(days.count) days, spread out."
    }

    private var spoken: String {
        let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let chosen = days.sorted().map { names[$0] }
        return chosen.isEmpty ? "No training days chosen." : chosen.joined(separator: ", ")
    }
}

#Preview {
    @Previewable @State var place = Place.profile
    ProfileScreen(place: $place)
        .environment(ProfileStore(defaults: UserDefaults(suiteName: "preview")!))
}
