import SwiftUI

enum AppTab: Int, CaseIterable, Identifiable {
    case profile, workout, ranks, history
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .profile: return "Profile"
        case .workout: return "Workout"
        case .ranks: return "Ranks"
        case .history: return "History"
        }
    }
    var symbol: String {
        switch self {
        case .profile: return "person.crop.circle.fill"
        case .workout: return "dumbbell.fill"
        case .ranks: return "trophy.fill"
        case .history: return "chart.bar.xaxis"
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: AppStore
    @State private var tab: AppTab = .profile
    private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .bottom) {
            AppBackground()

            ZStack {
                page(.profile) { ProfileView(tab: $tab) }
                page(.workout) { WorkoutView() }
                page(.ranks) { RanksView() }
                page(.history) { HistoryView() }
            }
            .animation(.easeOut(duration: 0.18), value: tab)

            VStack(spacing: 10) {
                if store.active != nil && !store.showActive {
                    ActiveWorkoutBar()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                GlassTabBar(selection: $tab)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 4)
            .animation(Theme.spring, value: store.active != nil && !store.showActive)
        }
        .ignoresSafeArea(.keyboard)
        .fullScreenCover(isPresented: $store.showActive) {
            ActiveWorkoutView().environmentObject(store)
        }
        .sheet(item: $store.lastSummary) { summary in
            WorkoutSummaryView(summary: summary).environmentObject(store)
        }
        .background {
            Color.clear
                .fullScreenCover(isPresented: Binding(get: { !store.profile.onboarded }, set: { _ in })) {
                    OnboardingView().environmentObject(store)
                }
        }
        .onReceive(ticker) { _ in store.tick() }
    }

    @ViewBuilder
    private func page<V: View>(_ t: AppTab, @ViewBuilder _ content: () -> V) -> some View {
        content()
            .opacity(tab == t ? 1 : 0)
            .scaleEffect(tab == t ? 1 : 0.985)
            .allowsHitTesting(tab == t)
            .accessibilityHidden(tab != t)
    }
}

// MARK: - Liquid glass tab bar

struct GlassTabBar: View {
    @Binding var selection: AppTab
    @Namespace private var ns
    @State private var bounce: [AppTab: Int] = [:]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    if selection != tab { Haptics.select() }
                    bounce[tab, default: 0] += 1
                    withAnimation(Theme.snappy) { selection = tab }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 19, weight: .semibold))
                            .symbolEffect(.bounce, value: bounce[tab, default: 0])
                        Text(tab.title).font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(selection == tab ? Color.white : Color.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background {
                        if selection == tab {
                            Capsule()
                                .fill(Theme.accent.opacity(0.28))
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                                .matchedGeometryEffect(id: "tabPill", in: ns)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(6)
        .liquidGlass(Capsule(), interactive: true)
        .shadow(color: .black.opacity(0.45), radius: 20, y: 8)
    }
}

// MARK: - Minimized active workout

struct ActiveWorkoutBar: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        if let s = store.active {
            Button {
                Haptics.tap()
                store.showActive = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.success)
                        .symbolEffect(.pulse)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(s.name).font(.subheadline.weight(.bold)).lineLimit(1)
                        TimelineView(.periodic(from: .now, by: 1)) { ctx in
                            Text("\(fmtDuration(ctx.date.timeIntervalSince(s.start))) · \(s.completedSets) sets")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    Spacer()
                    if let end = store.restEnd {
                        TimelineView(.periodic(from: .now, by: 1)) { ctx in
                            Label(fmtDuration(end.timeIntervalSince(ctx.date)), systemImage: "timer")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(Theme.accent2)
                        }
                    }
                    Image(systemName: "chevron.up").font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(height: 58)
                .liquidGlass(Capsule(), interactive: true, tint: Theme.accent.opacity(0.22))
            }
            .buttonStyle(.pressable)
        }
    }
}
