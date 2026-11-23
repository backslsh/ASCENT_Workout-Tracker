import SwiftUI

// MARK: - Body heatmap

private struct BodyRegion {
    enum Kind { case capsule, ellipse, rounded }
    let group: MuscleGroup?
    let x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat
    let kind: Kind
}

/// Hand-placed regions on a 100 × 200 canvas.
private enum BodyMap {
    static let shared: [BodyRegion] = [
        .init(group: nil, x: 50, y: 13, w: 18, h: 22, kind: .ellipse),
        .init(group: nil, x: 50, y: 27, w: 9, h: 7, kind: .rounded),
        .init(group: nil, x: 20, y: 84, w: 8, h: 24, kind: .capsule),
        .init(group: nil, x: 80, y: 84, w: 8, h: 24, kind: .capsule),
    ]

    static let front: [BodyRegion] = shared + [
        .init(group: .shoulders, x: 31, y: 38, w: 16, h: 14, kind: .ellipse),
        .init(group: .shoulders, x: 69, y: 38, w: 16, h: 14, kind: .ellipse),
        .init(group: .chest, x: 41, y: 48, w: 17, h: 16, kind: .rounded),
        .init(group: .chest, x: 59, y: 48, w: 17, h: 16, kind: .rounded),
        .init(group: .biceps, x: 24, y: 58, w: 9, h: 22, kind: .capsule),
        .init(group: .biceps, x: 76, y: 58, w: 9, h: 22, kind: .capsule),
        .init(group: .core, x: 50, y: 76, w: 20, h: 34, kind: .rounded),
        .init(group: .core, x: 37, y: 78, w: 6, h: 26, kind: .capsule),
        .init(group: .core, x: 63, y: 78, w: 6, h: 26, kind: .capsule),
        .init(group: nil, x: 50, y: 100, w: 30, h: 10, kind: .rounded),
        .init(group: .legs, x: 41, y: 128, w: 14, h: 44, kind: .capsule),
        .init(group: .legs, x: 59, y: 128, w: 14, h: 44, kind: .capsule),
        .init(group: .legs, x: 41, y: 172, w: 9, h: 34, kind: .capsule),
        .init(group: .legs, x: 59, y: 172, w: 9, h: 34, kind: .capsule),
    ]

    static let back: [BodyRegion] = shared + [
        .init(group: .back, x: 50, y: 36, w: 22, h: 10, kind: .rounded),
        .init(group: .shoulders, x: 31, y: 38, w: 16, h: 14, kind: .ellipse),
        .init(group: .shoulders, x: 69, y: 38, w: 16, h: 14, kind: .ellipse),
        .init(group: .back, x: 40, y: 58, w: 15, h: 26, kind: .rounded),
        .init(group: .back, x: 60, y: 58, w: 15, h: 26, kind: .rounded),
        .init(group: .triceps, x: 24, y: 58, w: 9, h: 22, kind: .capsule),
        .init(group: .triceps, x: 76, y: 58, w: 9, h: 22, kind: .capsule),
        .init(group: .back, x: 50, y: 84, w: 16, h: 16, kind: .rounded),
        .init(group: .glutes, x: 41, y: 104, w: 19, h: 18, kind: .ellipse),
        .init(group: .glutes, x: 59, y: 104, w: 19, h: 18, kind: .ellipse),
        .init(group: .glutes, x: 41, y: 134, w: 13, h: 36, kind: .capsule),
        .init(group: .glutes, x: 59, y: 134, w: 13, h: 36, kind: .capsule),
        .init(group: .legs, x: 41, y: 172, w: 11, h: 32, kind: .capsule),
        .init(group: .legs, x: 59, y: 172, w: 11, h: 32, kind: .capsule),
    ]
}

private struct BodyFigure: View {
    let regions: [BodyRegion]
    let selected: MuscleGroup?
    let color: (MuscleGroup?) -> Color
    let onTap: (MuscleGroup) -> Void

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width / 100, geo.size.height / 200)
            let ox = (geo.size.width - 100 * s) / 2
            ZStack(alignment: .topLeading) {
                ForEach(regions.indices, id: \.self) { i in
                    let r = regions[i]
                    let isSel = r.group != nil && r.group == selected
                    shape(r)
                        .fill(color(r.group))
                        .overlay(shape(r).stroke(isSel ? Color.white : Color.white.opacity(0.10), lineWidth: isSel ? 2 : 0.75))
                        .frame(width: r.w * s, height: r.h * s)
                        .position(x: ox + r.x * s, y: r.y * s)
                        .onTapGesture { if let g = r.group { onTap(g) } }
                }
            }
        }
        .aspectRatio(0.5, contentMode: .fit)
    }

    private func shape(_ r: BodyRegion) -> AnyShape {
        switch r.kind {
        case .capsule: return AnyShape(Capsule())
        case .ellipse: return AnyShape(Ellipse())
        case .rounded: return AnyShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
    }
}

struct MuscleHeatmapCard: View {
    enum Mode: String, CaseIterable { case rank = "Rank", recency = "Recency" }

    @EnvironmentObject var store: AppStore
    @State private var mode: Mode = .rank
    @State private var selected: MuscleGroup?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Body Map").font(.headline)
                Spacer()
                Picker("Mode", selection: $mode.animation(Theme.spring)) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
            }
            HStack(spacing: 24) {
                figure(BodyMap.front, "FRONT")
                figure(BodyMap.back, "BACK")
            }
            .frame(height: 250)
            .frame(maxWidth: .infinity)

            if let g = selected {
                NavigationLink(value: g) { selectedRow(g) }
                    .buttonStyle(.pressable)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                legend
            }
        }
        .card()
        .animation(Theme.spring, value: selected)
    }

    private func figure(_ regions: [BodyRegion], _ label: String) -> some View {
        VStack(spacing: 6) {
            BodyFigure(regions: regions, selected: selected, color: color(for:)) { g in
                Haptics.select()
                selected = (selected == g ? nil : g)
            }
            Text(label).font(.system(size: 9, weight: .heavy)).tracking(1.2).foregroundStyle(Theme.textTertiary)
        }
    }

    private func color(for g: MuscleGroup?) -> Color {
        guard let g else { return Color.white.opacity(0.07) }
        switch mode {
        case .rank:
            guard let r = store.groupRank(g) else { return Color.white.opacity(0.10) }
            return r.color.opacity(0.9)
        case .recency:
            return Self.recencyColor(store.daysSince(store.lastTrained(g)))
        }
    }

    static func recencyColor(_ days: Int?) -> Color {
        guard let d = days else { return Color.white.opacity(0.10) }
        switch d {
        case ...2: return Color(hex: 0xFF5D3D)
        case 3...4: return Color(hex: 0xFF9F43)
        case 5...7: return Color(hex: 0xFFD84D).opacity(0.75)
        default: return Color(hex: 0x4DA3FF).opacity(0.45)
        }
    }

    private func selectedRow(_ g: MuscleGroup) -> some View {
        let r = store.groupRank(g)
        let days = store.daysSince(store.lastTrained(g))
        return HStack(spacing: 12) {
            MuscleIcon(group: g, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(g.name).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                Text("\(r?.title ?? "Unranked") · \(BalanceCard.daysText(days))")
                    .font(.caption)
                    .foregroundStyle(r?.color ?? Theme.textSecondary)
            }
            Spacer()
            RankBadge(rank: r, size: 30)
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.textTertiary)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.05)))
    }

    @ViewBuilder
    private var legend: some View {
        switch mode {
        case .rank:
            Text("Colored by your rank in each muscle group. Tap a muscle for details.")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
        case .recency:
            HStack(spacing: 12) {
                dot(Self.recencyColor(0), "0–2d")
                dot(Self.recencyColor(3), "3–4d")
                dot(Self.recencyColor(6), "5–7d")
                dot(Self.recencyColor(9), "8d+")
                dot(Self.recencyColor(nil), "Never")
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.textSecondary)
        }
    }

    private func dot(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(c).frame(width: 8, height: 8)
            Text(t)
        }
    }
}

// MARK: - Muscle balance

struct BalanceCard: View {
    @EnvironmentObject var store: AppStore

    static func daysText(_ d: Int?) -> String {
        guard let d else { return "never trained" }
        switch d {
        case 0: return "trained today"
        case 1: return "trained yesterday"
        default: return "\(d) days ago"
        }
    }

    private struct Row: Identifiable {
        let group: MuscleGroup
        let days: Int?
        let sets: Int
        var id: MuscleGroup { group }
        var age: Int { days ?? 999 }
    }

    private var rows: [Row] {
        MuscleGroup.allCases
            .map { g -> Row in Row(group: g, days: store.daysSince(store.lastTrained(g)), sets: store.recentSets(g)) }
            .sorted { a, b in a.sets == b.sets ? a.age < b.age : a.sets > b.sets }
    }

    var body: some View {
        let rows = self.rows
        let neglected: [Row] = rows.filter { $0.age >= 7 }.sorted { $0.age > $1.age }
        let maxSets = max(1, rows.map { $0.sets }.max() ?? 1)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Muscle Balance").font(.headline)
                    Text(headline(neglected.map { $0.group }))
                        .font(.caption)
                        .foregroundStyle(neglected.isEmpty ? Theme.success : Theme.warning)
                }
                Spacer()
                Text("SETS · 7 DAYS").font(.system(size: 9, weight: .heavy)).tracking(1).foregroundStyle(Theme.textTertiary)
            }
            VStack(spacing: 9) {
                ForEach(rows) { row in
                    let stale = row.age >= 7
                    HStack(spacing: 10) {
                        MuscleIcon(group: row.group, size: 26)
                        Text(row.group.name)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(width: 88, alignment: .leading)
                        ProgressBar(value: Double(row.sets) / Double(maxSets), colors: [row.group.color, row.group.color.opacity(0.6)], height: 6)
                        Text("\(row.sets)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .frame(width: 24, alignment: .trailing)
                        Text(shortDays(row.days))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(stale ? Theme.warning : Theme.textTertiary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }
        }
        .card()
    }

    private func headline(_ groups: [MuscleGroup]) -> String {
        switch groups.count {
        case 0: return "Nicely balanced: everything trained this week."
        case 1: return "\(groups[0].name) hasn't been trained in a week or more."
        case 2: return "\(groups[0].name) and \(groups[1].name) need some love."
        default: return "\(groups[0].name), \(groups[1].name) and \(groups.count - 2) more need some love."
        }
    }

    private func shortDays(_ d: Int?) -> String {
        guard let d else { return "never" }
        return d == 0 ? "today" : "\(d)d ago"
    }
}
