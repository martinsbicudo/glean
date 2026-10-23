import Charts
import SwiftUI

struct GoalHeader: View {
    let space: Space
    let progress: StudyProgress

    var body: some View {
        let goal = progress.goal(for: space)
        HStack(spacing: 10) {
            GoalRing(goal: goal)
            Text("\(goal.done)/\(goal.goal) today").monospacedDigit()
            if progress.currentStreak > 0 {
                Text("·").foregroundStyle(.secondary)
                Label(StreakText.days(progress.currentStreak), systemImage: "flame.fill").foregroundStyle(.orange)
            }
            Spacer()
        }
        .font(.callout)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct GoalRing: View {
    let goal: GoalProgress

    var body: some View {
        ZStack {
            Circle().stroke(.quaternary, lineWidth: 4)
            Circle()
                .trim(from: 0, to: goal.fraction)
                .stroke(goal.reached ? Color.green : Brand.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if goal.reached { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.green) }
        }
        .frame(width: 22, height: 22)
        .accessibilityLabel("\(goal.done) of \(goal.goal) cards today")
    }
}

enum StreakText {
    static func days(_ count: Int) -> String { count == 1 ? "1 day" : "\(count) days" }
}

struct ProgressSection: View {
    let space: Space
    let progress: StudyProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress").font(.title3.weight(.semibold))
            HStack(spacing: 14) {
                Tile(value: StreakText.days(progress.currentStreak), label: "current streak")
                Tile(value: StreakText.days(progress.bestStreak), label: "best streak")
                Tile(value: progress.retention(for: space.id)?.percent.map { "\($0)%" } ?? "–", label: "remembered, last 30 days")
            }
            Chart(progress.last30Days(in: space.id)) { item in
                BarMark(x: .value("Day", item.day, unit: .day), y: .value("Reviews", item.count))
                    .foregroundStyle(Brand.accent)
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 140)
            Text("Reviews per day in \(space.name), last 30 days. The streak counts a day when you rated at least one card in any space.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if progress.retentions.count > 1 { otherSpaces }
        }
    }

    private var otherSpaces: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Remembered by space").font(.headline)
            ForEach(progress.retentions) { item in
                HStack {
                    Text(item.name)
                    Spacer()
                    Text(item.percent.map { "\($0)% of \(item.reviews) reviews" } ?? "no reviews").foregroundStyle(.secondary)
                }
            }
        }
    }
}
