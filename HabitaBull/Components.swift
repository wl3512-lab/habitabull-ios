//
// the pieces every screen is built from, matching components/ui.tsx and
// components/Stepper.tsx on the web. one orange button per screen, never two

import SwiftUI

// the small uppercase heading above a section
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.label)
            .tracking(1.1)
            .foregroundStyle(.dim)
    }
}

// the big full-width button. primary is the one orange action, ghost is the rest
struct Pill: View {
    enum Variant { case primary, ghost }

    let title: String
    var variant = Variant.primary
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.head)
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(textColor)
                .background(fillColor, in: .capsule)
                .overlay(Capsule().strokeBorder(edgeColor))
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }

    private var isPrimary: Bool { variant == .primary && isEnabled }
    private var textColor: Color { isPrimary ? .ground : isEnabled ? .brandCyan : .dim }
    private var fillColor: Color { isPrimary ? .action : .clear }
    private var edgeColor: Color { isPrimary ? .action : .lineStrong }
}

// a raised panel
struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.card, in: .rect(cornerRadius: 16))
    }
}

// the one-thumb control: big round buttons at the edges, the number in the
// middle. tap the number to type it, because 200 lb is a lot of taps
struct NumberStepper: View {
    let label: String
    @Binding var value: Double
    let step: Double
    var minimum = 0.0
    var maximum = 2000.0
    var unit = ""

    @State private var draft = ""
    @FocusState private var typing: Bool

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: label)
                HStack(spacing: 8) {
                    roundButton("minus", name: "Decrease \(label)", disabled: value <= minimum) {
                        value = max(minimum, value - step)
                    }
                    VStack(spacing: 0) {
                        number
                        if !unit.isEmpty {
                            Text(unit).font(.captionText).foregroundStyle(.dim)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    roundButton("plus", name: "Increase \(label)", disabled: value >= maximum) {
                        value = min(maximum, value + step)
                    }
                }
            }
        }
        .onChange(of: typing) { _, isTyping in
            if !isTyping { commit() }
        }
    }

    // the field stays on screen but invisible, so focus can land on it at once
    private var number: some View {
        ZStack {
            Text(value.formatted())
                .opacity(typing ? 0 : 1)
                .onTapGesture {
                    draft = value.formatted()
                    typing = true
                }
                .accessibilityLabel("Type \(label) instead")
            TextField("", text: $draft)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .focused($typing)
                .opacity(typing ? 1 : 0)
                .allowsHitTesting(typing)
                .accessibilityHidden(!typing)
        }
        .font(.hero)
        .monospacedDigit()
        .foregroundStyle(.fg)
        .toolbar {
            if typing {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { typing = false }
                }
            }
        }
    }

    // whole numbers for reps, halves for weight, and always inside the limits
    private func commit() {
        guard let typed = Double(draft) else { return }
        let rounded = step == 1 ? typed.rounded() : (typed * 2).rounded() / 2
        value = min(maximum, max(minimum, rounded))
    }

    private func roundButton(_ symbol: String, name: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .frame(width: 56, height: 56)
                .foregroundStyle(.fg)
                .background(.raise, in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .accessibilityLabel(name)
    }
}

// the set you're doing now, and nothing else
struct SetRow: View {
    @Binding var weight: Double
    @Binding var reps: Double
    var weightStep = 5.0
    var showsWeight = true

    var body: some View {
        VStack(spacing: 12) {
            if showsWeight {
                NumberStepper(label: "Weight", value: $weight, step: weightStep, unit: "lb")
            }
            NumberStepper(label: "Reps", value: $reps, step: 1, minimum: 1, maximum: 200, unit: "reps")
        }
    }
}

// a bar per set, so you can see where you are at a glance. green is logged,
// the lighter one is the set you're on
struct SetBar: View {
    let sets: [LoggedSet]
    let current: Int
    var onReopen: ((Int) -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            ForEach(sets.indices, id: \.self) { i in
                // drawn 6 tall, tapped at 44, so a mis-logged set is easy to fix
                Button {
                    onReopen?(i)
                } label: {
                    Capsule()
                        .fill(color(for: i))
                        .frame(height: 6)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(!sets[i].done)
                .accessibilityLabel(label(for: i))
            }
        }
        .padding(.vertical, -19)
    }

    private func label(for i: Int) -> String {
        if sets[i].done {
            return "Set \(i + 1), logged \(sets[i].weight.formatted()) pounds for \(sets[i].reps). Tap to redo"
        }
        return "Set \(i + 1), not logged"
    }

    private func color(for i: Int) -> Color {
        if sets[i].done { return .done }
        return i == current ? .lineStrong : .raise
    }
}

// change how many sets a lift has, from the rest screen. the count in the
// middle is the feedback
struct SetCountRow: View {
    let setsLeft: Int
    let canDrop: Bool
    let onDrop: () -> Void
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button("− Set", action: onDrop)
                .foregroundStyle(.dim)
                .disabled(!canDrop)
                .opacity(canDrop ? 1 : 0.4)
                .accessibilityLabel("Remove the last set from this lift")
            Text("\(setsLeft) \(setsLeft == 1 ? "set" : "sets") left")
                .font(.bodyText)
                .monospacedDigit()
                .foregroundStyle(.dim)
            Button("+ Set", action: onAdd)
                .foregroundStyle(.brandCyan)
                .accessibilityLabel("Add a set to this lift")
        }
        .font(.head)
        .frame(maxWidth: .infinity, minHeight: 44)
    }
}

// the mascot. the width sets the size and the drawing keeps its own shape
struct Bull: View {
    enum Pose: String {
        case stand = "mascot"
        case cheer = "mascot-cheer"
        case confused = "mascot-confused"
        case rest = "mascot-rest"
        case show = "mascot-show"
    }

    var pose = Pose.stand
    var size = 132.0

    var body: some View {
        Image(pose.rawValue)
            .resizable()
            .scaledToFit()
            .frame(width: size)
            .accessibilityHidden(true)
    }
}

#Preview {
    @Previewable @State var weight = 95.0
    @Previewable @State var reps = 8.0

    VStack(spacing: 16) {
        Bull(pose: .cheer, size: 96)
        SetRow(weight: $weight, reps: $reps)
        Pill(title: "Log set") {}
        Pill(title: "Add a lift", variant: .ghost) {}
    }
    .padding(24)
    .frame(maxHeight: .infinity)
    .background(.ground)
}
