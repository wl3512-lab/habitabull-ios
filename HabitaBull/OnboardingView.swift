//
// the first run: a name, a reason, and how long you rest. then you lift.
//
// ported from the web app's components/Onboarding.tsx, including the thinking
// behind it. the week is not asked here. her own lo-fi testing found goal
// first tested badly, people want to log a workout before they commit to
// anything, and asking a beginner which days they will train before they have
// trained once asks for a promise they have no basis to make. the app picks a
// safe week and offers the real one after the first finished workout.

import SwiftUI
import HabitaBullKit

/// Reasons that are their own payoff.
///
/// This is the point of the question rather than a copywriting preference:
/// the research behind the deck found that self-chosen reasons hold people and
/// imposed ones don't, so the suggestions must not quietly teach the other
/// frame. No "lose 10 lb", no "look good for summer". Anyone who wants those
/// can still type them. The app just won't propose them.
private let reasons = [
    "I want to feel strong.",
    "I want more energy in the day.",
    "It clears my head.",
    "I like how it feels afterwards.",
    "I want to keep up with my friends.",
]

/// Seconds, and the words describe the number rather than promise something
/// the timer then breaks. These used to be paces that multiplied a per-lift
/// base, so "about a minute" delivered 1:20 on a squat. Whatever is chosen
/// here is exactly what the timer counts, on every lift.
private let restChoices: [(seconds: Int, label: String, hint: String)] = [
    (60, "1 minute", "Keeps the pace up. Good for lighter work."),
    (90, "1 minute 30", "Right for most lifts."),
    (150, "2 minutes 30", "For heavy strength work."),
]

struct OnboardingView: View {
    @Environment(ProfileStore.self) private var profiles

    // the timer already owns this key and reads it on every rest, so
    // onboarding writes where the timer already looks instead of inventing a
    // second copy that can disagree with it
    @AppStorage("restSeconds") private var restSeconds = 90

    @State private var step = 0
    @State private var name = ""
    @State private var motivation = ""

    var body: some View {
        Group {
            switch step {
            case 0: WelcomeStep(name: $name) { step = 1 }
            case 1: WhyStep(motivation: $motivation, onSkip: finish) { step = 2 }
            default: RestStep(seconds: $restSeconds, onSkip: finish, onDone: finish)
            }
        }
        .animation(.easeOut(duration: 0.2), value: step)
    }

    private func finish() {
        // starting today, so the first thing the app says is not "rest"
        let today = Calendar.current.component(.weekday, from: .now) - 1
        profiles.save(Profile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            motivation: motivation.trimmingCharacters(in: .whitespacesAndNewlines),
            trainingDays: Schedule.placeDays(3, today: today),
            createdAt: .now
        ))
    }
}

// MARK: - one, your name

private struct WelcomeStep: View {
    @Binding var name: String
    let onContinue: () -> Void

    @FocusState private var typing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Bull(size: 150)
                .frame(maxWidth: .infinity)

            // the wordmark is written, not uppercased: the display face would
            // throw away the capital B in the middle of the name, and the
            // camel case is the identity rather than a styling accident
            VStack(spacing: 4) {
                Text("Welcome to")
                    .font(.titleText)
                    .foregroundStyle(.ground.opacity(0.8))
                Text("HabitaBull")
                    .font(.hero)
                    .foregroundStyle(.ground)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 14)

            Text("What's your name?")
                .font(.emphasis)
                .foregroundStyle(.ground)
                .padding(.top, 36)

            ZStack(alignment: .leading) {
                if name.isEmpty {
                    Text("Your name")
                        .font(.figure)
                        .foregroundStyle(.ground.opacity(0.55))
                }
                TextField("", text: $name)
                    .font(.figure)
                    .foregroundStyle(.ground)
                    .tint(.ground)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($typing)
                    .onSubmit(onContinue)
                    .accessibilityLabel("Your name")
            }
            .padding(.top, 4)
            .padding(.bottom, 8)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(.ground.opacity(typing ? 1 : 0.7))
                    .frame(height: 2)
            }

            Spacer(minLength: 40)

            Pill(title: "Continue", variant: .onCyan, action: onContinue)
            Text("One quick question, then you lift.")
                .font(.captionText)
                .foregroundStyle(.ground.opacity(0.75))
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.brandCyan)
    }
}

// MARK: - two, why you lift

private struct WhyStep: View {
    @Binding var motivation: String
    let onSkip: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingPage(
            label: "One question",
            title: "Why do you lift?",
            blurb: "Your answer, in your words. We show it back to you on the days you don't feel like it, and we never rewrite it.",
            onSkip: onSkip,
            footnote: "One quick thing, then you lift.",
            action: "Continue",
            onAction: onContinue
        ) {
            SectionLabel(text: "I work out because…")
                .padding(.top, 26)

            // the editor carries the card rather than sitting on one, so the
            // caret and the text land where the placeholder was
            ZStack(alignment: .topLeading) {
                if motivation.isEmpty {
                    Text("I want to be strong and feel good.")
                        .font(.head)
                        .foregroundStyle(.dim)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $motivation)
                    .font(.head)
                    .foregroundStyle(.fg)
                    .tint(.brandCyan)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 84)
                    .accessibilityLabel("Why you lift")
            }
            .padding(13)
            .background(.card, in: .rect(cornerRadius: 16))
            .padding(.top, 8)

            Text("Or start from one of these:")
                .font(.bodyText)
                .foregroundStyle(.dim)
                .padding(.top, 16)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(reasons, id: \.self) { reason in
                    let said = reason.hasSuffix(".") ? String(reason.dropLast()) : reason
                    let chosen = motivation == reason
                    Button {
                        motivation = chosen ? "" : reason
                    } label: {
                        Text(said)
                            .font(.head)
                            .foregroundStyle(chosen ? .ground : .dim)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                            .background(chosen ? Color.brandCyan : .clear, in: .capsule)
                            .overlay(Capsule().strokeBorder(chosen ? .brandCyan : .lineStrong))
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(chosen ? [.isSelected] : [])
                }
            }
            .padding(.top, 10)
        }
    }
}

// MARK: - three, how long you rest

private struct RestStep: View {
    @Binding var seconds: Int
    let onSkip: () -> Void
    let onDone: () -> Void

    @State private var showingNote = false

    var body: some View {
        OnboardingPage(
            label: "Your pace",
            title: "How long do you rest?",
            blurb: "Between sets. Change it any time.",
            onSkip: onSkip,
            footnote: nil,
            action: "Start my first workout",
            onAction: onDone
        ) {
            VStack(spacing: 10) {
                ForEach(restChoices, id: \.seconds) { choice in
                    let chosen = seconds == choice.seconds
                    Button {
                        seconds = choice.seconds
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(choice.label).font(.emphasis).foregroundStyle(.fg)
                            Text(choice.hint).font(.bodyText).foregroundStyle(.dim)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(chosen ? Color.brandCyan.opacity(0.1) : .clear,
                                    in: .rect(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(chosen ? .brandCyan : .lineStrong))
                        .contentShape(.rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    // the two lines are one choice, so they are read as one
                    // thing rather than as a heading and a stray sentence
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("rest-\(choice.seconds)")
                    .accessibilityAddTraits(chosen ? [.isSelected] : [])
                }
            }
            .padding(.top, 26)

            Button {
                withAnimation(.easeOut(duration: 0.2)) { showingNote.toggle() }
            } label: {
                Text("Do men and women rest differently?")
                    .font(.bodyText)
                    .foregroundStyle(.brandCyan)
            }
            .buttonStyle(.plain)
            .padding(.top, 16)

            if showingNote {
                Text("A little. Studies suggest women often recover faster between sets, while men moving heavier absolute loads tend to need more. But how hard the set felt and which lift it was matter more than either, so pick what fits today and change it whenever.")
                    .font(.bodyText)
                    .foregroundStyle(.dim)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.card, in: .rect(cornerRadius: 16))
                    .padding(.top, 10)
            }
        }
    }
}

// MARK: - the shape both dark steps share

/// Label and Skip, a headline, a blurb, whatever the step is actually asking,
/// then one button at the bottom. Written once so the two steps cannot drift
/// apart by a few points of padding.
private struct OnboardingPage<Content: View>: View {
    let label: String
    let title: String
    let blurb: String
    let onSkip: () -> Void
    let footnote: String?
    let action: String
    let onAction: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        // the button belongs at the bottom of the screen when the step is
        // short and below the content when the text size makes it long, which
        // is one line of geometry rather than a guess at a phone's height
        GeometryReader { screen in
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    SectionLabel(text: label, color: .brandCyan)
                    Spacer()
                    Button("Skip", action: onSkip)
                        .font(.head)
                        .foregroundStyle(.dim)
                        .buttonStyle(.plain)
                }

                Text(title)
                    .font(.figure)
                    .foregroundStyle(.fg)
                    .padding(.top, 18)

                Text(blurb)
                    .font(.emphasis)
                    .foregroundStyle(.dim)
                    .padding(.top, 6)

                content

                Spacer(minLength: 40)

                if let footnote {
                    Text(footnote)
                        .font(.bodyText)
                        .foregroundStyle(.dim)
                        .padding(.bottom, 12)
                }
                Pill(title: action, action: onAction)
            }
            .padding(24)
            .frame(maxWidth: .infinity, minHeight: screen.size.height, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        }
        .background(.ground)
    }
}

#Preview {
    OnboardingView().environment(ProfileStore(defaults: UserDefaults(suiteName: "preview")!))
}
