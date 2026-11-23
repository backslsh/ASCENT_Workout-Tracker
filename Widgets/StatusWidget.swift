import WidgetKit
import SwiftUI

struct StatusEntry: TimelineEntry {
    let date: Date
    let snap: WidgetSnapshot?
}

struct StatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatusEntry {
        StatusEntry(date: Date(), snap: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
        completion(StatusEntry(date: Date(), snap: WidgetSnapshot.load() ?? .sample))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        let now = Date()
        let cal = Calendar.current
        let tomorrow = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86400))
        let entry = StatusEntry(date: now, snap: WidgetSnapshot.load())
        // The app also reloads the widget whenever your data changes.
        completion(Timeline(entries: [entry], policy: .after(tomorrow)))
    }
}

struct AscendStatusWidget: Widget {
    let kind = "AscendStatus"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatusProvider()) { entry in
            StatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Ascend")
        .description("Your streak, weekly goal, overall rank and quick-start routines.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct StatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StatusEntry

    private var snap: WidgetSnapshot { entry.snap ?? .empty }
    private var week: Int { TrainingMath.workoutsThisWeek(snap.sessionDates, now: entry.date) }
    private var streak: Int { TrainingMath.weekStreak(snap.sessionDates, now: entry.date) }
    private var goal: Int { max(1, snap.weeklyGoal) }
    private var accent: Color { Color(hex: snap.accent) }
    private var accent2: Color { Color(hex: snap.accent2) }
    private var rankColors: [Color] { snap.overallColors.map { Color(hex: $0) } }

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if family == .systemSmall || family == .systemMedium {
                    background
                } else {
                    Color.clear
                }
            }
            .widgetURL(URL(string: snap.activeStart != nil ? "ascend://workout" : "ascend://open"))
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        case .systemMedium: medium
        default: small
        }
    }

    private var background: some View {
        ZStack {
            Color(hex: 0x07070A)
            RadialGradient(colors: [accent.opacity(0.38), .clear], center: .topLeading, startRadius: 0, endRadius: 190)
            RadialGradient(colors: [accent2.opacity(0.16), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 200)
        }
    }

    // MARK: Home screen

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                WidgetRankBadge(colors: rankColors, symbol: snap.overallSymbol, size: 36)
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 0) {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill").foregroundStyle(Color(hex: 0xFF9F43))
                        Text("\(streak)")
                    }
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    Text("wk streak")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
            }
            Spacer(minLength: 6)
            if let start = snap.activeStart {
                Text("IN PROGRESS")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(accent2)
                Text(start, style: .timer)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                Text(snap.activeName ?? "Workout")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .lineLimit(1)
            } else if entry.snap == nil {
                Text("Open Ascend")
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                Text("to sync your stats")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.6))
            } else {
                Text(snap.overallTitle ?? "Unranked")
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(LinearGradient(colors: rankColors.isEmpty ? [.white, .gray] : rankColors,
                                                    startPoint: .leading, endPoint: .trailing))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(week)/\(goal) this week")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .padding(.bottom, 5)
                weekBar
            }
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private var weekBar: some View {
        if goal <= 7 {
            HStack(spacing: 3) {
                ForEach(0..<goal, id: \.self) { i in
                    Capsule()
                        .fill(i < week
                              ? AnyShapeStyle(LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing))
                              : AnyShapeStyle(Color.white.opacity(0.15)))
                        .frame(height: 5)
                }
            }
        } else {
            ProgressView(value: Double(min(week, goal)), total: Double(goal))
                .tint(accent)
        }
    }

    private var medium: some View {
        HStack(spacing: 14) {
            small.frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 6) {
                Text("QUICK START")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(Color.white.opacity(0.5))
                if snap.activeStart != nil {
                    Link(destination: URL(string: "ascend://workout")!) { row("Resume workout", "play.fill") }
                } else if snap.pinned.isEmpty {
                    Link(destination: URL(string: "ascend://start")!) { row("Empty workout", "bolt.fill") }
                } else {
                    ForEach(snap.pinned.prefix(3)) { r in
                        Link(destination: URL(string: "ascend://routine/\(r.id.uuidString)")!) { row(r.name, "play.fill") }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.white)
    }

    private func row(_ name: String, _ icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing)))
            Text(name)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color.white.opacity(0.08)))
    }

    // MARK: Lock screen

    private var circular: some View {
        Gauge(value: Double(min(week, goal)), in: 0...Double(goal)) {
            Image(systemName: "dumbbell.fill")
        } currentValueLabel: {
            Text("\(week)")
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label("\(streak)-week streak", systemImage: "flame.fill")
                .font(.headline)
                .widgetAccentable()
            Text("\(week)/\(goal) workouts this week")
                .font(.caption)
            Text(snap.overallTitle ?? "Unranked")
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        Label("\(week)/\(goal) workouts · \(streak) wk streak", systemImage: "dumbbell.fill")
    }
}
