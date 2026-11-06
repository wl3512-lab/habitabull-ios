//
// the plate math, same rules as the web app's lib/plates.ts. the weight stays
// the one source of truth, and the plates are worked out from it

import SwiftUI

enum Plates {
    static let sizes = [45.0, 25, 10, 5, 2.5]
    static let maxPerSide = 10

    // a real sleeve only holds so much: about 16 inches. bumper-ish thicknesses in inches
    static let sleeve = 16.0
    static func thickness(_ size: Double) -> Double {
        switch size {
        case 45...: 2.4
        case 25...: 1.6
        case 10...: 1.1
        case 5...: 0.8
        default: 0.6
        }
    }
    static func room(_ perSide: [Double]) -> Double {
        sleeve - perSide.map(thickness).reduce(0, +)
    }
    static func fits(_ size: Double, on perSide: [Double]) -> Bool {
        perSide.count < maxPerSide && thickness(size) <= room(perSide) + 0.001
    }
    // the most the bar can hold: as many 45s as fit
    static func heaviest(bar: Double) -> Double {
        bar + 2 * 45 * floor(sleeve / thickness(45))
    }

    // heaviest first, for one side. exact is false if the number can't be
    // loaded, like 47.5 on a 45 bar
    static func load(_ weight: Double, bar: Double) -> (perSide: [Double], achieved: Double, exact: Bool) {
        var left = (weight - bar) / 2
        guard left > 0 else { return ([], bar, weight == bar) }
        var perSide: [Double] = []
        for size in sizes {
            while left >= size && fits(size, on: perSide) {
                perSide.append(size)
                left -= size
            }
        }
        let achieved = total(perSide, bar: bar)
        return (perSide, achieved, achieved == weight)
    }

    static func total(_ perSide: [Double], bar: Double) -> Double {
        bar + 2 * perSide.reduce(0, +)
    }

    static func words(_ perSide: [Double]) -> String {
        perSide.isEmpty ? "Empty bar" : perSide.map(\.description).map { $0.replacingOccurrences(of: ".0", with: "") }.joined(separator: " · ") + " a side"
    }
}

// the plates on one end of the bar, as you'd see them at a rack: heaviest
// against the collar. the whole end is one button that takes the outer plate
// off, because a 2.5 alone is too thin for a thumb
struct Sleeve: View {
    let plates: [Double]
    let mirror: Bool
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            ZStack(alignment: mirror ? .leading : .trailing) {
                Rectangle().fill(.lineStrong).frame(height: 10)
                HStack(spacing: 2) {
                    ForEach(Array((mirror ? plates : plates.reversed()).enumerated()), id: \.offset) { _, p in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(p >= 25 ? Color.brandCyan : Color.brandCyanSoft)
                            .frame(width: p >= 25 ? 13 : p >= 10 ? 10 : 7)
                            .frame(height: max(26, p / 45 * 76))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(plates.isEmpty)
        .accessibilityHidden(mirror)
        .accessibilityLabel(plates.last.map { "Take off the outer \($0.formatted()) pound plate" } ?? "No plates on")
    }
}

// load the bar, drawn. it takes the place of the Weight stepper on barbell
// lifts when you pick "Load the bar". the weight stays the one number; the
// plates are worked out from it
struct PlateBar: View {
    @Binding var weight: Double

    @AppStorage("barWeight") private var savedBar = 45.0
    // the bar for this lift. a weight lighter than your usual bar means a lighter
    // bar (a 30 lb squat is a 30 lb bar, no plates), without changing the saved one
    @State private var bar = 45.0
    @State private var added: [Double] = []   // newest last, so "remove last" takes it off

    private var loaded: (perSide: [Double], achieved: Double, exact: Bool) {
        Plates.load(weight, bar: bar)
    }
    private var full: Bool { !Plates.sizes.contains { Plates.fits($0, on: loaded.perSide) } }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    SectionLabel(text: "On the bar")
                    Spacer()
                    Text(loaded.achieved.formatted())
                        .font(.figure).foregroundStyle(.fg).monospacedDigit()
                    Text("lb").font(.bodyText).foregroundStyle(.dim)
                }

                // the whole bar: a loaded sleeve at each end of a long bare shaft
                HStack(spacing: 0) {
                    Sleeve(plates: loaded.perSide, mirror: false) { removeOuter() }
                        .frame(width: 100)
                    collar
                    Rectangle().fill(.lineStrong).frame(height: 6).frame(maxWidth: .infinity)
                    collar
                    Sleeve(plates: loaded.perSide, mirror: true) { removeOuter() }
                        .frame(width: 100)
                }
                .padding(.horizontal, 12)
                .frame(height: 96)
                .background(.ground, in: .rect(cornerRadius: 12))

                Text(loaded.perSide.isEmpty
                     ? "Just the bar. Tap a plate below to put one on each end."
                     : "\(Plates.words(loaded.perSide)). Tap an end of the bar to take one off.")
                    .font(.bodyText).foregroundStyle(.dim)

                if !loaded.exact {
                    Text(full && weight > loaded.achieved
                         ? "\(weight.formatted()) lb is more than a bar holds. Full, it's \(loaded.achieved.formatted())."
                         : "\(weight.formatted()) lb needs a plate you may not have. Nearest is \(loaded.achieved.formatted()).")
                        .font(.bodyText).foregroundStyle(.fault)
                } else if full {
                    Text("That's a full bar. Take a plate off to change it.")
                        .font(.bodyText).foregroundStyle(.dim)
                }

                HStack(spacing: 6) {
                    ForEach(Plates.sizes, id: \.self) { size in
                        let fits = Plates.fits(size, on: loaded.perSide)
                        Button(size.formatted()) {
                            weight = Plates.total(loaded.perSide + [size], bar: bar)
                            added.append(size)
                        }
                        .font(.head).foregroundStyle(.fg).monospacedDigit()
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(.raise, in: .capsule)
                        .disabled(!fits)
                        .opacity(fits ? 1 : 0.4)
                        .accessibilityLabel("Add one \(size.formatted()) pound plate to each side")
                    }
                }
                .buttonStyle(.plain)

                HStack {
                    Button {
                        removeLast()
                    } label: {
                        Label("Remove last plate", systemImage: "arrow.uturn.backward")
                    }
                    .foregroundStyle(.brandCyan)
                    Spacer()
                    Button("Strip") { weight = bar; added = [] }
                        .foregroundStyle(.dim)
                }
                .font(.head)
                .disabled(loaded.perSide.isEmpty)
                .opacity(loaded.perSide.isEmpty ? 0.4 : 1)
                .frame(minHeight: 44)

                HStack {
                    SectionLabel(text: "Bar")
                    Spacer()
                    smallButton("minus", "Lighter bar") { setBar(bar - 5) }
                    Text("\(bar.formatted()) lb")
                        .font(.head).foregroundStyle(.fg).monospacedDigit()
                        .frame(minWidth: 64)
                    smallButton("plus", "Heavier bar") { setBar(bar + 5) }
                }
            }
        }
        .onAppear { bar = weight > 0 && weight < savedBar ? weight : savedBar }
        .onChange(of: weight) { _, w in if w > 0 && w < bar { bar = w } }
    }

    private var collar: some View {
        RoundedRectangle(cornerRadius: 2).fill(.dim).frame(width: 6, height: 30)
    }

    private func smallButton(_ icon: String, _ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.head).foregroundStyle(.fg)
                .frame(width: 44, height: 44)
                .background(.raise, in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
    }

    // the bar you set here is saved for every barbell lift
    private func setBar(_ b: Double) {
        let plates = loaded.perSide
        bar = min(100, max(0, b))
        savedBar = bar
        weight = Plates.total(plates, bar: bar)
    }

    // tapping an end takes off its outer plate, the way a bar is unloaded
    private func removeOuter() {
        var plates = loaded.perSide
        guard let gone = plates.popLast() else { return }
        if let k = added.lastIndex(of: gone) { added.remove(at: k) }
        weight = Plates.total(plates, bar: bar)
    }

    // takes off the plate you added last; with nothing added here, the outer one
    private func removeLast() {
        var plates = loaded.perSide
        guard !plates.isEmpty else { return }
        if let last = added.popLast(), let k = plates.lastIndex(of: last) {
            plates.remove(at: k)
        } else {
            plates.removeLast()
        }
        weight = Plates.total(plates, bar: bar)
    }
}

// choose how to set the weight on a barbell lift. remembered for every barbell
// lift. it's the system segmented control, so the thumb slides the way iOS does
struct WeightInputSwitch: View {
    @Binding var plates: Bool

    var body: some View {
        Picker("Weight entry method", selection: $plates.animation(.smooth(duration: 0.3))) {
            Text("Use + / −").tag(false)
            Text("Load the bar").tag(true)
        }
        .pickerStyle(.segmented)
        .controlSize(.large)
    }
}

#Preview {
    @Previewable @State var weight = 135.0
    PlateBar(weight: $weight).padding().background(.ground)
}
