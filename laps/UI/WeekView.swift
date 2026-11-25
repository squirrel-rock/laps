import SwiftUI
import Charts

struct WeekView: View {
    @Environment(WalkStore.self) private var store

    var body: some View {
        let days = store.lastSevenDays()
        let total = days.reduce(0) { $0 + $1.laps }
        let best = days.map(\.laps).max() ?? 0

        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Laps each day")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.text)
                    WeekChart(days: days, todayKey: store.todayKey)
                        .frame(height: 300)
                    HStack(spacing: 16) {
                        legendItem(color: Theme.teal, dashed: false, text: "Goal: 9 laps")
                        legendItem(color: Theme.warm, dashed: true, text: "4 sets: 12")
                    }
                    .accessibilityHidden(true)
                }
                .card()

                VStack(spacing: 0) {
                    SummaryRow(title: "Laps this week", value: "\(total)")
                    Divider()
                    SummaryRow(title: "That's", value: LapMath.setsShort(total))
                    Divider()
                    SummaryRow(title: "Best day", value: LapMath.plural(best, "lap"))
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
                                HStack {
                                    Text(dayTitle(day.day))
                                        .foregroundStyle(Theme.text)
                                    Spacer()
                                    Text(LapMath.plural(day.lapCount, "lap"))
                                        .foregroundStyle(Theme.darkTeal)
                                        .fontWeight(.semibold)
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(Theme.secondaryText)
                                }
                                .font(.system(.body, design: .rounded))
                                .frame(minHeight: 52)
                                .contentShape(Rectangle())
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

    private func dayTitle(_ key: String) -> String {
        if key == store.todayKey { return "Today" }
        guard let d = store.date(forKey: key) else { return key }
        return d.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private func legendItem(color: Color, dashed: Bool, text: String) -> some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(.clear)
                .frame(width: 22, height: 3)
                .overlay(
                    Path { p in p.move(to: .init(x: 0, y: 1.5)); p.addLine(to: .init(x: 22, y: 1.5)) }
                        .stroke(color, style: StrokeStyle(lineWidth: 3, dash: dashed ? [4, 3] : []))
                )
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
        }
    }
}

struct WeekChart: View {
    let days: [(key: String, date: Date, laps: Int)]
    let todayKey: String

    var body: some View {
        let top = max(LapMath.dailyGoal, days.map(\.laps).max() ?? 0) + 2

        Chart {
            ForEach(days, id: \.key) { day in
                BarMark(
                    x: .value("Day", label(day)),
                    y: .value("Laps", day.laps),
                    width: .ratio(0.62)
                )
                .foregroundStyle(day.key == todayKey ? Theme.teal : Theme.teal.opacity(0.75))
                .cornerRadius(8)
                .annotation(position: .top, spacing: 4) {
                    Text("\(day.laps)")
                        .font(.system(.callout, design: .rounded).weight(.bold))
                        .foregroundStyle(day.laps == 0 ? Theme.secondaryText : Theme.darkTeal)
                }
                .accessibilityLabel(accessibleDay(day))
                .accessibilityValue("\(LapMath.plural(day.laps, "lap")), \(LapMath.setsShort(day.laps))")
            }

            RuleMark(y: .value("Goal", LapMath.dailyGoal))
                .foregroundStyle(Theme.teal)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .accessibilityLabel("Daily goal")
                .accessibilityValue("\(LapMath.dailyGoal)")
        }
        .chartYScale(domain: 0...top)
        .chartYAxis {
            AxisMarks(position: .leading, values: Array(stride(from: 0, through: top, by: 3))) { _ in
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

    private func label(_ day: (key: String, date: Date, laps: Int)) -> String {
        day.key == todayKey ? "Today" : day.date.formatted(.dateTime.weekday(.abbreviated))
    }

    private func accessibleDay(_ day: (key: String, date: Date, laps: Int)) -> String {
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
