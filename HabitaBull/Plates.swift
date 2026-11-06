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

// the whole bar, drawn: the same plates on both ends, mirrored. bigger plates
// are taller, like the real thing
struct BarDrawing: View {
    let perSide: [Double]
    var height = 32.0
    var onTapPlate: ((Int) -> Void)? = nil

    var body: some View {
        HStack(spacing: 2) {
            sleeveEnd
            ForEach(perSide.indices.reversed(), id: \.self) { plate($0) }
            collar
            Rectangle().fill(.lineStrong).frame(minWidth: 12, maxWidth: .infinity, maxHeight: max(3, height * 0.1))
            collar
            ForEach(perSide.indices, id: \.self) { plate($0) }
            sleeveEnd
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }

    private var sleeveEnd: some View {
        Rectangle().fill(.lineStrong).frame(width: height * 0.25, height: max(4, height * 0.16))
    }
    private var collar: some View {
        RoundedRectangle(cornerRadius: 1).fill(.dim).frame(width: max(3, height * 0.1), height: height * 0.5)
    }
    private func plate(_ i: Int) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(perSide[i] >= 25 ? Color.brandCyan : Color.dim)
            .frame(width: max(3, height * 0.1 * Plates.thickness(perSide[i])), height: height * (0.45 + perSide[i] / 45 * 0.55))
            .onTapGesture { onTapPlate?(i) }
    }
}

// the slim row under Weight, barbell lifts only. tap it to load the bar
struct PlateRow: View {
    let weight: Double
    let bar: Double
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                BarDrawing(perSide: Plates.load(weight, bar: bar).perSide, height: 26)
                    .frame(maxWidth: 170)
                Spacer()
                Text(Plates.words(Plates.load(weight, bar: bar).perSide))
                    .font(.bodyText)
                    .foregroundStyle(.dim)
                    .monospacedDigit()
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 48)
            .background(.card, in: .rect(cornerRadius: 16))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("On the bar: \(Plates.words(Plates.load(weight, bar: bar).perSide)). Tap to load the bar")
    }
}

// load the bar by plate instead of by number
struct LoadBarView: View {
    @Binding var weight: Double
    @AppStorage("barWeight") private var savedBar = 45.0
    // the bar for this lift. a weight lighter than your usual bar means a lighter
    // bar (a 30 lb squat is a 30 lb bar, no plates), without changing the saved one
    @State private var bar = 45.0
    @Environment(\.dismiss) private var dismiss
    @State private var added: [Double] = []   // plates added here, newest last, so undo takes the last one off

    private var loaded: (perSide: [Double], achieved: Double, exact: Bool) {
        Plates.load(weight, bar: bar)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .firstTextBaseline) {
                    SectionLabel(text: "On the bar")
                    Spacer()
                    Text("\(loaded.achieved.formatted()) lb")
                        .font(.figure)
                        .foregroundStyle(.fg)
                        .monospacedDigit()
                }

                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        BarDrawing(perSide: loaded.perSide, height: 72) { i in
                            var plates = loaded.perSide
                            let gone = plates.remove(at: i)
                            if let k = added.lastIndex(of: gone) { added.remove(at: k) }
                            weight = Plates.total(plates, bar: bar)
                        }
                        Text(Plates.words(loaded.perSide))
                            .font(.bodyText)
                            .foregroundStyle(.dim)
                        if !loaded.perSide.isEmpty {
                            Label("Tap any plate to take it off", systemImage: "hand.tap")
                                .font(.captionText)
                                .foregroundStyle(.brandCyan)
                        }
                    }
                }

                if !loaded.exact {
                    Text("\(weight.formatted()) lb can't be loaded with these plates.")
                        .font(.bodyText)
                        .foregroundStyle(.dim)
                }

                SectionLabel(text: "Tap to add one to each side")
                HStack(spacing: 8) {
                    ForEach(Plates.sizes, id: \.self) { size in
                        Button(size.formatted()) {
                            weight = Plates.total(loaded.perSide + [size], bar: bar)
                            added.append(size)
                        }
                        .font(.head)
                        .foregroundStyle(.fg)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(.raise, in: .capsule)
                        .disabled(!Plates.fits(size, on: loaded.perSide))
                        .opacity(Plates.fits(size, on: loaded.perSide) ? 1 : 0.35)
                        .accessibilityLabel("Add \(size.formatted()) pounds to each side")
                    }
                }
                .buttonStyle(.plain)

                HStack {
                    if !Plates.sizes.contains(where: { Plates.fits($0, on: loaded.perSide) }) {
                        Text("The bar's full.")
                    } else if !Plates.fits(45, on: loaded.perSide) {
                        Text("No room for another 45.")
                    }
                    Spacer()
                    Button {
                        removeLast()
                    } label: {
                        Label("Remove last plate", systemImage: "arrow.uturn.backward")
                    }
                    .font(.head)
                    .foregroundStyle(loaded.perSide.isEmpty ? Color.dim : Color.brandCyan)
                    .disabled(loaded.perSide.isEmpty)
                    .accessibilityLabel("Remove the last plate from each side")
                }
                .font(.bodyText)
                .foregroundStyle(.dim)
                .frame(minHeight: 44)

                NumberStepper(label: "Bar", value: Binding(get: { bar }, set: { bar = $0; savedBar = $0 }), step: 5, maximum: 100, unit: "lb")

                Spacer()

                Pill(title: "Strip the bar", variant: .ghost) { weight = bar; added = [] }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(.ground)
            .onAppear { bar = weight > 0 && weight < savedBar ? weight : savedBar }
            .navigationTitle("Load the bar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(.brandCyan)
    }
}

extension LoadBarView {
    // takes off the plate you added last. if you came in with the bar already
    // loaded, it takes the outermost (smallest) plate, the one you'd grab first
    fileprivate func removeLast() {
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

#Preview {
    @Previewable @State var weight = 135.0
    LoadBarView(weight: $weight)
}
