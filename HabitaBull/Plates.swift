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
                            .frame(height: max(22, p / 45 * 60))
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
    /// Which set this is editing, so the trail below can be dropped when she
    /// moves to another one.
    ///
    /// Watching the weight is not enough, and a codex audit 2026-11-17 said
    /// why: she can be on a set that weighs what the last one did. Log 155,
    /// then 145, then put a five a side on the third set to reach 155 again
    /// and tap the first set to fix it. The weight does not change, so nothing
    /// told this view it had changed set, and Undo gave the first set 145.
    var setKey: String = ""

    @AppStorage("barWeight") private var savedBar = 45.0
    // the bar for this lift. a weight lighter than your usual bar means a lighter
    // bar (a 30 lb squat is a 30 lb bar, no plates), without changing the saved one
    @State private var bar = 45.0
    /// What the bar read before each plate she added, newest last.
    ///
    /// This used to hold the plate sizes, and undo went looking on the bar for
    /// the size it was holding. The bar does not keep the plates you put on
    /// it: 45 and two fives is 65, which loads as a single ten a side, so undo
    /// looked for a five, found none, and took the ten off instead. One tap
    /// back to the empty bar from 65. The weight before the tap is the only
    /// thing undo needs to know.
    @State private var before: [Double] = []

    /// The weight this view wrote last, so a change it did not make can be
    /// told from one it did.
    ///
    /// The trail above is the plates she put on *this* set. The editor stays
    /// on screen while she picks a different set to correct, so without this
    /// the trail went with it: add a plate on the third set, tap the first set
    /// to fix it, and Undo put the third set's weight into the first one.
    /// A weight that arrives from outside is a different set, and a set with
    /// no trail of its own undoes by taking the outer plate off, which is what
    /// the bar in front of her actually looks like.
    /// Found by a codex audit 2026-11-17.
    @State private var mine: Double?

    private var loaded: (perSide: [Double], achieved: Double, exact: Bool) {
        Plates.load(weight, bar: bar)
    }
    private var full: Bool { !Plates.sizes.contains { Plates.fits($0, on: loaded.perSide) } }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    SectionLabel(text: Plates.words(loaded.perSide))
                    Spacer()
                    Text(loaded.achieved.formatted())
                        .font(.figure).foregroundStyle(.fg).monospacedDigit()
                        // so a test can say which number it means. The plate
                        // view has three numbers that can read 45: this one,
                        // the bar's own weight and a plate button.
                        .accessibilityIdentifier("plate-total")
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
                .frame(height: 76)
                .background(.ground, in: .rect(cornerRadius: 12))

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
                            before.append(weight)
                            mine = Plates.total(loaded.perSide + [size], bar: bar)
                            weight = mine ?? weight
                        }
                        .font(.head).foregroundStyle(.fg).monospacedDigit()
                        // five plates share the width, and at the largest
                        // text sizes "2.5" is wider than its fifth: it wrapped
                        // to "2." over "5" and spilled out of its capsule.
                        // a number that shrinks a little is readable, a number
                        // broken across two lines is not a number.
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(.raise, in: .capsule)
                        .disabled(!fits)
                        .opacity(fits ? 1 : 0.4)
                        .accessibilityLabel("Add one \(size.formatted()) pound plate to each side")
                    }
                }
                .buttonStyle(.plain)

                // plates on the left, the bar itself on the right, on one row
                // while they fit. at the largest text sizes they do not: the
                // three 44pt buttons and a bar label that will not wrap took
                // the whole width and SwiftUI squeezed Strip to nothing. A
                // button 0pt wide cannot be tapped however far you scroll, so
                // she could not strip the bar or change its weight at all.
                // Found by a codex audit 2026-11-16, reproduced on a
                // simulator at AccessibilityXXXL.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        plateControls
                        Spacer()
                        barControls
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) { plateControls; Spacer() }
                        HStack(spacing: 8) { barControls; Spacer() }
                    }
                }
            }
        }
        .onAppear { bar = barFor(weight) }
        // a different set is a different bar, whatever it weighs
        .onChange(of: setKey) { _, _ in
            before = []
            mine = nil
        }
        .onChange(of: weight) { _, w in
            // a weight this view wrote is a plate she just put on, and the
            // bar under it is the one she is standing over. A weight from
            // outside is a different set or a number she typed, so the bar is
            // read fresh from it. Reading it fresh either way snapped a 30 lb
            // bar back to 45 the moment she put a plate on it.
            let outside = w != mine
            if outside {
                before = []
                bar = barFor(w)
            }
            mine = nil
        }
    }

    /// The bar a weight implies: her usual one, or the weight itself when
    /// that is lighter, because a 30 lb squat is a 30 lb bar and no plates.
    ///
    /// This used to only ever shrink, and nothing put it back. Log a 30 lb
    /// set, then a 135 lb one, and the bar under the plates was still 30: the
    /// label read "30 lb bar", the plate maths was wrong by fifteen a side,
    /// and Strip set the weight to 30. A set change cleared the Undo trail
    /// and left the bar where the light set had pushed it, so correcting one
    /// set changed what another correction would do. Deliberately choosing a
    /// bar writes `savedBar` too, so reading from it never undoes her choice.
    /// Found by a codex audit 2026-11-17.
    private func barFor(_ w: Double) -> Double {
        w > 0 && w < savedBar ? w : savedBar
    }

    /// Undo and Strip, which only mean anything with a plate on.
    @ViewBuilder private var plateControls: some View {
        Group {
            Button {
                removeLast()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .foregroundStyle(.brandCyan)
            .accessibilityLabel("Remove last plate")
            // the word itself was the target: 37 by 20, the smallest thing
            // in the app. The frame is invisible and exists only so a thumb
            // has 44pt to land on. It has to be inside the Button: padding
            // put on the outside is space around the button, not part of it.
            Button {
                mine = bar
                weight = bar
                before = []
            } label: {
                Text("Strip")
                    .fixedSize()
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.dim)
        }
        .font(.head)
        .disabled(loaded.perSide.isEmpty)
        .opacity(loaded.perSide.isEmpty ? 0.4 : 1)
    }

    /// The bar under the plates, and what it weighs.
    @ViewBuilder private var barControls: some View {
        smallButton("minus", "Lighter bar") { setBar(bar - 5) }
        Text("\(bar.formatted()) lb bar")
            .font(.bodyText).foregroundStyle(.dim).monospacedDigit()
            .fixedSize()
            .accessibilityLabel("Bar weight \(bar.formatted()) pounds")
        smallButton("plus", "Heavier bar") { setBar(bar + 5) }
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
        // those weights were against the old bar
        before = []
        bar = min(100, max(0, b))
        savedBar = bar
        mine = Plates.total(plates, bar: bar)
        weight = mine ?? weight
    }

    // tapping an end takes off its outer plate, the way a bar is unloaded
    private func removeOuter() {
        var plates = loaded.perSide
        guard plates.popLast() != nil else { return }
        // she unloaded the bar herself, so the trail no longer describes it
        before = []
        mine = Plates.total(plates, bar: bar)
        weight = mine ?? weight
    }

    // puts the bar back to what it read before the last plate she added; with
    // nothing added here, the outer one comes off
    private func removeLast() {
        if let was = before.popLast() {
            mine = was
            weight = was
            return
        }
        var plates = loaded.perSide
        guard !plates.isEmpty else { return }
        plates.removeLast()
        mine = Plates.total(plates, bar: bar)
        weight = mine ?? weight
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
