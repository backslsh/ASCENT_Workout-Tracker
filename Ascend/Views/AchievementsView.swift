import SwiftUI

struct AchievementsView: View {
    @EnvironmentObject var store: AppStore

    private var items: [Achievement] {
        Achievements.all.sorted { a, b in
            let ua = store.unlocked[a.id], ub = store.unlocked[b.id]
            switch (ua, ub) {
            case let (x?, y?): return x > y
            case (.some, nil): return true
            case (nil, .some): return false
            default: return store.achievementProgress(a) > store.achievementProgress(b)
            }
        }
    }

    var body: some View {
        let done = Achievements.all.filter { store.unlocked[$0.id] != nil }.count
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.08), lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: Double(done) / Double(max(1, Achievements.all.count)))
                            .stroke(Theme.accentGradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Image(systemName: "rosette").font(.title.weight(.bold)).foregroundStyle(Theme.accentGradient)
                    }
                    .frame(width: 76, height: 76)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(done) of \(Achievements.all.count)")
                            .font(.system(.title, design: .rounded).weight(.heavy))
                        Text("achievements unlocked").font(.subheadline).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .card(padding: 18)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(items) { a in AchievementTile(achievement: a) }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 150)
        }
        .scrollIndicators(.hidden)
        .background(AppBackground())
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AchievementBadge: View {
    let achievement: Achievement
    let unlocked: Bool
    var progress: Double = 1
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle()
                .fill(unlocked
                      ? AnyShapeStyle(LinearGradient(colors: [achievement.color, achievement.color.opacity(0.55)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                      : AnyShapeStyle(Color.white.opacity(0.06)))
                .shadow(color: unlocked ? achievement.color.opacity(0.45) : .clear, radius: size * 0.2)
            if !unlocked {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(achievement.color.opacity(0.8), style: StrokeStyle(lineWidth: max(2, size * 0.05), lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            Image(systemName: achievement.symbol)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(unlocked ? Color.white : Color.white.opacity(0.3))
                .shadow(color: .black.opacity(unlocked ? 0.3 : 0), radius: 1, y: 1)
        }
        .frame(width: size, height: size)
    }
}

struct AchievementTile: View {
    @EnvironmentObject var store: AppStore
    let achievement: Achievement

    var body: some View {
        let date = store.unlocked[achievement.id]
        let progress = store.achievementProgress(achievement)
        VStack(alignment: .leading, spacing: 10) {
            AchievementBadge(achievement: achievement, unlocked: date != nil, progress: progress, size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(achievement.title).font(.subheadline.weight(.bold)).lineLimit(1).minimumScaleFactor(0.8)
                Text(store.achievementDetail(achievement))
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let date {
                Label(date.formatted(.dateTime.month(.abbreviated).day().year()), systemImage: "checkmark.seal.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(achievement.color)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressBar(value: progress, colors: [achievement.color, achievement.color.opacity(0.6)], height: 4)
                    Text(store.achievementProgressText(achievement))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .card(padding: 14, radius: 20)
        .opacity(date == nil ? 0.85 : 1)
    }
}
