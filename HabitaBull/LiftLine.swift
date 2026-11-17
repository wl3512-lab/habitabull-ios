//
// one lift, over weeks.
//
// A line, not bars. Bars read as independent quantities and the thing worth
// seeing across a training block is the direction between the points, not the
// height of any one of them.
//
// Deliberately unlabelled along the bottom. These series are irregular, you
// train when you train, so evenly spaced points are already a small lie and
// hanging dates under them would make it a confident one. The caption says
// how many days it is drawn from and leaves it at that.

import SwiftUI
import HabitaBullKit

struct LiftLine: View {
    let points: [LiftPoint]
    /// What the line is, for anyone who cannot see it.
    let lift: String

    /// The readings and their range, worked out once when the view is made.
    ///
    /// These used to be computed properties. `bounds` mapped every point
    /// through `value`, `value` asked `byReps`, and `byReps` scanned every
    /// point; then `at` read `bounds` again for each point it placed, and both
    /// the line and the fill placed every point. Two years of bodyweight
    /// chin-ups is 300 points, which came to tens of millions of checks to
    /// draw one chart, every time Progress redrew.
    /// Found by a codex audit 2026-11-16.
    private let readings: [Double]
    private let byReps: Bool
    private let bounds: (low: Double, high: Double)

    init(points: [LiftPoint], lift: String) {
        self.points = points
        self.lift = lift
        let reps = points.allSatisfy { $0.weight == 0 }
        self.byReps = reps
        let readings = points.map { reps ? Double($0.reps) : $0.weight }
        self.readings = readings
        let low = readings.min() ?? 0
        let high = readings.max() ?? 0
        // a flat run is the common case early on, three days at the same
        // weight, and it would divide by zero. a span of one puts the line
        // through the middle of the box, which is the honest picture: nothing
        // moved. padding the range otherwise keeps the peak off the ceiling,
        // where a line touching the edge reads as clipped.
        let span = high - low == 0 ? 1 : high - low
        let pad = span * 0.1
        self.bounds = (low - pad, high + pad)
    }

    private var height: CGFloat { 116 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { proxy in
                let box = CGSize(width: proxy.size.width, height: height)
                ZStack {
                    if points.count > 1 {
                        area(in: box).fill(Color.brandCyan.opacity(0.12))
                        line(in: box)
                            .stroke(Color.brandCyan,
                                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    }
                    // the latest reading, which is the number anyone is
                    // actually looking for
                    if let last = points.last {
                        Circle()
                            .fill(.fg)
                            .frame(width: 8, height: 8)
                            .position(at(points.count - 1, value(last), in: box))
                    }
                }
            }
            .frame(height: height)
            .accessibilityElement()
            .accessibilityLabel(spoken)

            Text(caption)
                .font(.captionText)
                .foregroundStyle(.dim)
        }
    }

    private var caption: String {
        points.count == 1
            ? "First one logged. Come back and this becomes a line."
            : "\(points.count) days"
    }

    private var spoken: String {
        guard let first = points.first, let last = points.last else { return lift }
        if points.count == 1 { return "\(lift): one day logged, \(value(first).formatted()) \(unit)." }
        return "\(lift): \(points.count) days, \(value(first).formatted()) to \(value(last).formatted()) \(unit)."
    }

    /// A lift with no weight on it is not a flat line at zero, it is a line
    /// drawn in reps. Chin-ups and push-ups get better by the rep, and a line
    /// that cannot say so is worse than no line: it says nothing is happening.
    /// Decided once, in `init`.
    private var unit: String { byReps ? "reps" : "lb" }

    private func value(_ point: LiftPoint) -> Double {
        byReps ? Double(point.reps) : point.weight
    }

    // MARK: - geometry

    private func at(_ index: Int, _ reading: Double, in box: CGSize) -> CGPoint {
        let x = points.count == 1
            ? box.width / 2
            : box.width * CGFloat(index) / CGFloat(points.count - 1)
        let (low, high) = bounds
        let share = (reading - low) / (high - low)
        return CGPoint(x: x, y: box.height - box.height * share)
    }

    private func line(in box: CGSize) -> Path {
        Path { path in
            for (index, reading) in readings.enumerated() {
                let spot = at(index, reading, in: box)
                index == 0 ? path.move(to: spot) : path.addLine(to: spot)
            }
        }
    }

    /// The same line, closed along the floor so the fill has a baseline.
    private func area(in box: CGSize) -> Path {
        Path { path in
            path.addPath(line(in: box))
            path.addLine(to: CGPoint(x: box.width, y: box.height))
            path.addLine(to: CGPoint(x: 0, y: box.height))
            path.closeSubpath()
        }
    }
}

#Preview {
    VStack {
        LiftLine(points: [LiftPoint(date: "2026-10-28", weight: 135, reps: 8),
                          LiftPoint(date: "2026-11-04", weight: 145, reps: 8),
                          LiftPoint(date: "2026-11-11", weight: 155, reps: 5)],
                 lift: "Back Squat")
        LiftLine(points: [LiftPoint(date: "2026-11-11", weight: 155, reps: 5)], lift: "Deadlift")
    }
    .padding(24)
    .background(.card)
}
