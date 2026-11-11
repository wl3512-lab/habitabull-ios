//
// her reason, in her own words, where she can see it and change it.
//
// The launch screen shows it, under whether today is a workout day or a rest
// day, but shows it read-only: a splash is no place for a text field. This is
// where she changes it, from her profile, which is the only screen it is on
// now and the reason it kept its own file.

import SwiftUI

struct ReasonCard: View {
    let profile: Profile?
    let onSave: (String) -> Void

    @State private var editing = false
    @State private var draft = ""

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 0) {
                Bull(size: 76)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 14)

                HStack(alignment: .firstTextBaseline) {
                    SectionLabel(text: "You work out because")
                    Spacer()
                    if !editing, profile?.why != nil {
                        Button("Change") {
                            draft = profile?.why ?? ""
                            editing = true
                        }
                        .font(.bodyText)
                        .foregroundStyle(.brandCyan)
                        .accessibilityIdentifier("change-reason")
                    }
                }

                if editing {
                    TextField("", text: $draft, axis: .vertical)
                        .font(.emphasis)
                        .foregroundStyle(.fg)
                        .tint(.brandCyan)
                        .lineLimit(2...4)
                        .padding(13)
                        .background(.raise, in: .rect(cornerRadius: 14))
                        .padding(.top, 12)
                        .accessibilityLabel("Why you work out")

                    HStack(spacing: 10) {
                        Pill(title: "Save") {
                            onSave(draft)
                            editing = false
                        }
                        Pill(title: "Cancel", variant: .ghost) { editing = false }
                    }
                    .padding(.top, 12)
                } else if let why = profile?.why {
                    Text("\u{201C}\(why)\u{201D}")
                        .font(.titleText)
                        .foregroundStyle(.fg)
                        .padding(.top, 10)
                } else {
                    Button("Say why, in your words") {
                        draft = ""
                        editing = true
                    }
                    .font(.emphasis)
                    .foregroundStyle(.brandCyan)
                    .padding(.top, 10)
                    .accessibilityIdentifier("add-reason")
                }
            }
        }
    }
}

