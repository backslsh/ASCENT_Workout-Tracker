import ActivityKit
import WidgetKit
import SwiftUI

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LiveLockScreenView(context: context)
                .activityBackgroundTint(Color(hex: 0x07070A).opacity(0.88))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "ascend://workout"))
        } dynamicIsland: { context in
            let a1 = Color(hex: context.attributes.accent)
            let a2 = Color(hex: context.attributes.accent2)
            let range = context.state.restRange(stale: context.isStale)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.attributes.name).lineLimit(1)
                    } icon: {
                        Image(systemName: "dumbbell.fill").foregroundStyle(a1)
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.start, style: .timer)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 72, alignment: .trailing)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    LiveRestSection(context: context, compact: true)
                        .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: range != nil ? "timer" : "dumbbell.fill")
                    .foregroundStyle(a1)
            } compactTrailing: {
                if let range {
                    Text(timerInterval: range, countsDown: true)
                        .monospacedDigit()
                        .foregroundStyle(a2)
                        .frame(width: 42)
                } else {
                    Text(context.attributes.start, style: .timer)
                        .monospacedDigit()
                        .frame(width: 48)
                }
            } minimal: {
                Image(systemName: range != nil ? "timer" : "dumbbell.fill")
                    .foregroundStyle(a1)
            }
            .widgetURL(URL(string: "ascend://workout"))
            .keylineTint(a1)
        }
    }
}

struct LiveLockScreenView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        let a1 = Color(hex: context.attributes.accent)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "dumbbell.fill").foregroundStyle(a1)
                Text(context.attributes.name).font(.headline).lineLimit(1)
                Spacer()
                Text(context.attributes.start, style: .timer)
                    .font(.system(.headline, design: .rounded).monospacedDigit())
                    .multilineTextAlignment(.trailing)
                    .frame(width: 84, alignment: .trailing)
            }
            LiveRestSection(context: context, compact: false)
        }
        .padding(16)
        .foregroundStyle(.white)
    }
}

struct LiveRestSection: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>
    let compact: Bool

    var body: some View {
        let a1 = Color(hex: context.attributes.accent)
        let a2 = Color(hex: context.attributes.accent2)
        let st = context.state
        if let range = st.restRange(stale: context.isStale) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("REST")
                        .font(.caption2.weight(.heavy))
                        .tracking(1)
                        .foregroundStyle(Color.white.opacity(0.6))
                    Text("Next: \(st.exercise)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .lineLimit(1)
                    Spacer()
                    Text(timerInterval: range, countsDown: true)
                        .font(.system(compact ? .title3 : .title2, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(a2)
                        .frame(width: compact ? 70 : 90, alignment: .trailing)
                }
                ProgressView(timerInterval: range, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(a1)
            }
        } else {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.isStale && st.restEnd != nil ? "REST'S OVER" : "UP NEXT")
                        .font(.caption2.weight(.heavy))
                        .tracking(1)
                        .foregroundStyle(a2)
                    Text(st.exercise)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
                Spacer()
                Text("\(st.setsDone)/\(st.setsTotal) sets")
                    .font(.subheadline.weight(.bold).monospacedDigit())
            }
        }
    }
}
