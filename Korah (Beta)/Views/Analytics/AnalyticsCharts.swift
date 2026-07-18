import SwiftUI
import Charts

// MARK: - Analytics chart pieces
// The Swift Charts + custom-drawn components used by SATAnalyticsView, kept
// separate so the screen itself stays readable. Colors follow the design
// guide: kSuccess/kError for outcomes, harder difficulties render darker and
// sit below easier ones in each stack (mirrors the web activity trend).

// MARK: - Activity trend (weekly stacked bars)

struct AnalyticsTrendChart: View {
    let buckets: [AnalyticsWeekBucket]

    /// Stack order: wrong under correct, hard (darkest) at the bottom of each
    /// outcome band.
    private struct Segment: Identifiable {
        let week: Date
        let label: String    // "Wrong H" … "Correct E" — stable stacking key
        let count: Int
        let color: Color
        var id: String { "\(week.timeIntervalSince1970)|\(label)" }
    }

    private var segments: [Segment] {
        let order: [(correct: Bool, diff: String, opacity: Double)] = [
            (false, "H", 1.0), (false, "M", 0.72), (false, "E", 0.45),
            (true, "H", 1.0), (true, "M", 0.72), (true, "E", 0.45),
        ]
        return buckets.flatMap { bucket in
            order.compactMap { entry in
                let count = entry.correct
                    ? bucket.correct[entry.diff, default: 0]
                    : bucket.wrong[entry.diff, default: 0]
                guard count > 0 else { return nil }
                let base: Color = entry.correct ? .kSuccess : .kError
                return Segment(week: bucket.weekStart,
                               label: "\(entry.correct ? "C" : "W")-\(entry.diff)",
                               count: count,
                               color: base.opacity(entry.opacity))
            }
        }
    }

    var body: some View {
        Chart(segments) { segment in
            BarMark(
                x: .value("Week", segment.week, unit: .weekOfYear),
                y: .value("Questions", segment.count)
            )
            .foregroundStyle(segment.color)
            .cornerRadius(2)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(.caption2)
                    .foregroundStyle(Color.kTextTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Color.kBorder.opacity(0.35))
                AxisValueLabel()
                    .font(.caption2)
                    .foregroundStyle(Color.kTextTertiary)
            }
        }
        .frame(height: 180)
    }
}

// MARK: - Time donut

struct AnalyticsDonutSlice: Identifiable {
    let label: String
    let seconds: Int
    let color: Color
    var id: String { label }
}

struct AnalyticsTimeDonut: View {
    let slices: [AnalyticsDonutSlice]
    let centerTitle: String
    let centerCaption: String

    private var visible: [AnalyticsDonutSlice] { slices.filter { $0.seconds > 0 } }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ZStack {
                if visible.isEmpty {
                    Circle()
                        .stroke(Color.kBorder.opacity(0.5), lineWidth: 14)
                        .frame(width: 120, height: 120)
                } else {
                    Chart(visible) { slice in
                        SectorMark(
                            angle: .value("Time", slice.seconds),
                            innerRadius: .ratio(0.72),
                            angularInset: 2
                        )
                        .foregroundStyle(slice.color)
                        .cornerRadius(4)
                    }
                    .frame(width: 132, height: 132)
                }
                VStack(spacing: 1) {
                    Text(centerTitle)
                        .font(.jakarta(19, relativeTo: .title3).weight(.bold))
                        .foregroundStyle(Color.kTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.numericText())
                    Text(centerCaption)
                        .font(.kCaption2)
                        .foregroundStyle(Color.kTextTertiary)
                }
                .frame(width: 88)
            }

            VStack(alignment: .leading, spacing: 5) {
                ForEach(slices) { slice in
                    HStack(spacing: 6) {
                        Circle().fill(slice.color).frame(width: 8, height: 8)
                        Text(slice.label)
                            .font(.kCaption)
                            .foregroundStyle(Color.kTextSecondary)
                        Spacer(minLength: 4)
                        Text(AnalyticsFormat.duration(slice.seconds))
                            .font(.kCaption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(Color.kTextPrimary)
                            .contentTransition(.numericText())
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Accuracy capsule bar

struct AnalyticsAccuracyBar: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.kBorder.opacity(0.5))
                Capsule()
                    .fill(tint)
                    .frame(width: max(6, geo.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: 7)
    }
}

// MARK: - Consistency heatmap

struct AnalyticsHeatmap: View {
    let weeks: [SATAnalyticsModel.HeatWeek]
    let maxCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .top, spacing: 4) {
                ForEach(weeks) { week in
                    VStack(spacing: 4) {
                        ForEach(Array(week.counts.enumerated()), id: \.offset) { _, count in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(cellColor(count))
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            HStack(spacing: 5) {
                Text("Less")
                ForEach([0.0, 0.33, 0.66, 1.0], id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(level == 0 ? Color.kBorder.opacity(0.4) : Color.kSuccess.opacity(0.25 + level * 0.75))
                        .frame(width: 10, height: 10)
                }
                Text("More")
            }
            .font(.kCaption2)
            .foregroundStyle(Color.kTextTertiary)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func cellColor(_ count: Int?) -> Color {
        guard let count else { return Color.clear }
        guard count > 0, maxCount > 0 else { return Color.kBorder.opacity(0.4) }
        let level = Double(count) / Double(maxCount)
        return Color.kSuccess.opacity(0.25 + level * 0.75)
    }
}

// MARK: - Pacing quadrant tile

struct AnalyticsQuadrantTile: View {
    let title: String
    let count: Int
    let total: Int
    let tint: Color
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
                Text(title)
                    .font(.kCaption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(tint)

            Text(total > 0 ? "\(Int((Double(count) / Double(total) * 100).rounded()))%" : "—")
                .font(.jakarta(20, relativeTo: .title3).weight(.bold))
                .foregroundStyle(Color.kTextPrimary)
                .contentTransition(.numericText())

            Text("\(count) question\(count == 1 ? "" : "s")")
                .font(.kCaption2)
                .foregroundStyle(Color.kTextTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .fill(tint.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .stroke(tint.opacity(0.28), lineWidth: 1)
        )
    }
}
