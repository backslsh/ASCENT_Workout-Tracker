import SwiftUI

struct WorkoutSummaryView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let summary: WorkoutSummary
    @State private var appeared = false
    @State private var saved = false

    private var celebrate: Bool { !summary.prs.isEmpty || !summary.rankUps.isEmpty || !summary.achievements.isEmpty }
    private var s: WorkoutSession { summary.session }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 22) {
                    Image(systemName: celebrate ? "trophy.fill" : "checkmark.seal.fill")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(celebrate
                                         ? LinearGradient(colors: RankTier.gold.colors, startPoint: .top, endPoint: .bottom)
                                         : Theme.accentGradient)
                        .scaleEffect(appeared ? 1 : 0.3)
                        .opacity(appeared ? 1 : 0)
                        .padding(.top, 36)

                    VStack(spacing: 4) {
                        Text("Workout Complete").font(.system(.title, design: .rounded).weight(.heavy))
                        Text(s.name).font(.subheadline).foregroundStyle(Theme.textSecondary)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        StatTile(value: fmtShortDuration(s.duration), label: "Duration", symbol: "clock.fill", color: Theme.accent)
                        StatTile(value: store.weightText(s.volume), label: "Volume", symbol: "scalemass.fill", color: Theme.accent2)
                        StatTile(value: "\(s.completedSets)", label: "Sets", symbol: "checkmark.circle.fill", color: Theme.success)
                        StatTile(value: "\(summary.prs.count)", label: "Personal records", symbol: "flame.fill", color: Theme.warning)
                    }

                    if !summary.rankUps.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "Rank Ups")
                            ForEach(Array(summary.rankUps.enumerated()), id: \.element.id) { i, up in
                                rankUpRow(up)
                                    .opacity(appeared ? 1 : 0)
                                    .offset(y: appeared ? 0 : 24)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.25 + Double(i) * 0.08), value: appeared)
                            }
                        }
                    }

                    if !summary.achievements.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "Achievements Unlocked")
                            ForEach(Array(summary.achievements.enumerated()), id: \.element.id) { i, a in
                                HStack(spacing: 12) {
                                    AchievementBadge(achievement: a, unlocked: true, size: 44)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(a.title).font(.subheadline.weight(.bold))
                                        Text(store.achievementDetail(a)).font(.caption).foregroundStyle(Theme.textSecondary)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .card(padding: 12, radius: 18)
                                .opacity(appeared ? 1 : 0)
                                .scaleEffect(appeared ? 1 : 0.85)
                                .animation(.spring(response: 0.5, dampingFraction: 0.65).delay(0.35 + Double(i) * 0.1), value: appeared)
                            }
                        }
                    }

                    if !summary.prs.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "Personal Records")
                            VStack(spacing: 0) {
                                ForEach(summary.prs) { pr in
                                    let ex = store.exercise(pr.exerciseID) ?? .unknown
                                    HStack(spacing: 12) {
                                        MuscleIcon(group: ex.muscle, size: 32)
                                        Text(ex.name).font(.subheadline.weight(.semibold))
                                        Spacer()
                                        Text(store.setText(pr.set, ex)).font(.subheadline.weight(.bold)).foregroundStyle(RankTier.gold.colors[0])
                                    }
                                    .padding(12)
                                }
                            }
                            .card(padding: 0)
                        }
                    }

                    if s.routineID == nil {
                        SecondaryButton(title: saved ? "Saved to Routines" : "Save as Routine",
                                        symbol: saved ? "checkmark" : "square.and.arrow.down",
                                        tint: saved ? Theme.success : .white) {
                            guard !saved else { return }
                            store.saveAsRoutine(s)
                            withAnimation(Theme.snappy) { saved = true }
                        }
                    }

                    PrimaryButton(title: "Done") { dismiss() }
                        .padding(.bottom, 30)
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)

            if celebrate { ConfettiView().ignoresSafeArea() }
        }
        .presentationDragIndicator(.visible)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6).delay(0.1)) { appeared = true }
            if celebrate { Haptics.success() }
            if !summary.rankUps.isEmpty || !summary.achievements.isEmpty {
                Sounds.rankUp()
            } else if !summary.prs.isEmpty {
                Sounds.pr()
            } else {
                Sounds.finish()
            }
        }
    }

    private func rankUpRow(_ up: RankUp) -> some View {
        let ex = store.exercise(up.exerciseID) ?? .unknown
        return HStack(spacing: 12) {
            RankBadge(rank: up.from, size: 34).opacity(0.6)
            Image(systemName: "arrow.right").font(.caption.weight(.bold)).foregroundStyle(Theme.textTertiary)
            RankBadge(rank: up.to, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(ex.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(up.from == nil ? "Ranked: \(up.to.title)" : "\(up.from?.title ?? "") → \(up.to.title)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(up.to.color)
            }
            Spacer(minLength: 0)
        }
        .card(padding: 12, radius: 18)
    }
}
