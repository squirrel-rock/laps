import SwiftUI
import Charts

struct WeekView: View {
    @Environment(WalkStore.self) private var store

    var body: some View {
        let days = store.lastSevenDays()
        let goal = store.standingGoal
        let walking = days.reduce(0) { $0 + $1.walking }
        let laps = days.reduce(0) { $0 + $1.laps }
        let standing = days.reduce(0) { $0 + $1.standing }

        ScrollView {
            VStack(spacing: 20) {
                chartCard(
                    title: "Walking each day",
                    chart: StackedWeekChart(
                        days: days, todayKey: store.todayKey, goal: LapMath.dailyGoal,
                        goalColor: Theme.teal, numberColor: Theme.darkTeal,
                        what: "walking credits",
                        parts: { d in
                            let p = d.walkingParts
                            return [(p.carWalks, Theme.carWalk), (p.laps, Theme.teal), (p.gold, Theme.warm)]
                        }),
                    legend: [("Car walk", Theme.carWalk), ("Lap", Theme.teal), ("Gold bonus", Theme.warm)],
                    goalText: "Goal: \(LapMath.dailyGoal)", goalColor: Theme.teal)

                chartCard(
                    title: "Standing up each day",
                    chart: StackedWeekChart(
                        days: days, todayKey: store.todayKey, goal: goal,
                        goalColor: Theme.purple, numberColor: Theme.darkPurple,
                        what: "times up",
                        parts: { d in
                            let p = d.standingParts(goal: goal)
                            return [(p.lotion, Theme.cream), (p.violet, Theme.violet), (p.gold, Theme.warm)]
                        }),
                    legend: [("Face lotion", Theme.cream), ("Stood up", Theme.violet), ("Gold bonus", Theme.warm)],
                    goalText: "Goal: \(goal)", goalColor: Theme.purple)

                VStack(spacing: 0) {
                    SummaryRow(title: "Walking this week", value: "\(walking)")
                    Divider()
                    SummaryRow(title: "Laps", value: "\(laps) (\(LapMath.setsShort(laps)))")
                    Divider()
                    SummaryRow(title: "Times up this week", value: "\(standing)")
                }
                .card()

                if !store.recordedDays.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Day by day")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.text)
                            .padding(.bottom, 6)
                        ForEach(store.recordedDays, id: \.day) { day in
                            NavigationLink {
                                DayDetailView(dayKey: day.day)
                            } label: {
                                HStack(spacing: 10) {
                                    Text(dayTitle(day.day))
                                        .foregroundStyle(Theme.text)
                                    Spacer()
                                    Label("\(day.walkingCredits)", systemImage: "figure.walk")
                                        .foregroundStyle(Theme.darkTeal)
                                    Label("\(day.standingCredits)", systemImage: "figure.stand")
                                        .foregroundStyle(Theme.darkPurple)
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(Theme.secondaryText)
                                }
                                .fontWeight(.semibold)
                                .font(.system(.body, design: .rounded))
                                .frame(minHeight: 52)
                                .contentShape(Rectangle())
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("\(dayTitle(day.day)): \(day.walkingCredits) walking, \(day.standingCredits) times up")
                            }
                            .accessibilityHint("Shows details and lets you fix mistakes")
                            Divider()
                        }
                    }
                    .card()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("This Week")
    }

    private func chartCard(title: String, chart: StackedWeekChart, legend: [(String, Color)],
                           goalText: String, goalColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.text)
            chart.frame(height: 240)
            FlowLayout(spacing: 14) {
                ForEach(legend, id: \.0) { item in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3).fill(item.1).frame(width: 14, height: 14)
                        Text(item.0)
                    }
                }
                HStack(spacing: 6) {
                    Rectangle().fill(goalColor).frame(width: 22, height: 3)
                    Text(goalText)
                }
            }
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(Theme.secondaryText)
            .accessibilityHidden(true)
        }
        .card()
    }

    private func dayTitle(_ key: String) -> String {
        if key == store.todayKey { return "Today" }
        guard let d = store.date(forKey: key) else { return key }
        return d.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

/// A week of stacked bars (bottom part first) with a solid goal line across.
struct StackedWeekChart: View {
    let days: [WeekDay]
    let todayKey: String
    let goal: Int
    let goalColor: Color
    let numberColor: Color
    /// e.g. "walking credits", for VoiceOver.
    let what: String
    let parts: (WeekDay) -> [(Int, Color)]

    private struct Segment: Identifiable {
        let id: String
        let day: String
        let start: Int
        let end: Int
        let color: Color
    }

    var body: some View {
        let totals = days.map { parts($0).reduce(0) { $0 + $1.0 } }
        // Round up to the next 5 so both charts show a top label.
        let top = (max(goal, totals.max() ?? 0) + 2 + 4) / 5 * 5

        Chart {
            // Drawn first, so the day numbers sit on top of it.
            RuleMark(y: .value("Goal", goal))
                .foregroundStyle(goalColor)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .accessibilityLabel("Daily goal")
                .accessibilityValue("\(goal)")

            ForEach(Array(days.enumerated()), id: \.element.key) { i, day in
                let total = totals[i]
                ForEach(segments(day)) { seg in
                    BarMark(x: .value("Day", label(day)),
                            yStart: .value("From", seg.start), yEnd: .value("To", seg.end),
                            width: .ratio(0.62))
                        .foregroundStyle(seg.color)
                        .accessibilityHidden(true)
                }
                // An invisible point at the top of the bar carries the number above it.
                PointMark(x: .value("Day", label(day)), y: .value("Total", total))
                    .opacity(0)
                    .annotation(position: .top, spacing: 2) {
                        Text("\(total)")
                            .font(.system(.callout, design: .rounded).weight(.bold))
                            .foregroundStyle(total == 0 ? Theme.secondaryText : numberColor)
                            .padding(.horizontal, 3)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 4))   // stays readable over the goal line
                    }
                    .accessibilityLabel(accessibleDay(day))
                    .accessibilityValue("\(total) \(what)")
            }

        }
        .chartYScale(domain: 0...top)
        .chartYAxis {
            AxisMarks(position: .leading, values: Array(stride(from: 0, through: top, by: 5))) { _ in
                AxisGridLine().foregroundStyle(Theme.secondaryText.opacity(0.15))
                AxisValueLabel().font(.system(.caption, design: .rounded))
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let s = value.as(String.self) {
                        Text(s)
                            .font(.system(.subheadline, design: .rounded).weight(s == "Today" ? .bold : .regular))
                            .foregroundStyle(Theme.text)
                    }
                }
            }
        }
    }

    /// Parts stacked from the bottom; empty ones are skipped.
    private func segments(_ day: WeekDay) -> [Segment] {
        var out: [Segment] = [], y = 0
        for (i, part) in parts(day).enumerated() where part.0 > 0 {
            out.append(Segment(id: "\(day.key)-\(i)", day: day.key, start: y, end: y + part.0, color: part.1))
            y += part.0
        }
        return out
    }

    private func label(_ day: WeekDay) -> String {
        day.key == todayKey ? "Today" : day.date.formatted(.dateTime.weekday(.abbreviated))
    }

    private func accessibleDay(_ day: WeekDay) -> String {
        day.key == todayKey ? "Today" : day.date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
}

struct SummaryRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(Theme.secondaryText)
            Spacer()
            Text(value)
                .fontWeight(.bold)
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.trailing)
        }
        .font(.system(.title3, design: .rounded))
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
    }
}
