import SwiftUI
import Charts

struct BodyweightView: View {
    @EnvironmentObject var store: AppStore
    @State private var value: Double = 0
    @State private var date = Date()
    @State private var loaded = false

    private var units: UnitSystem { store.profile.units }

    var body: some View {
        let log = store.weightLog
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                stats(log)
                chart(log)
                logCard
                history(log)
                Text("Ranks use the bodyweight saved with each workout, so older ranks stay fair as your weight changes.")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 150)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(AppBackground())
        .navigationTitle("Bodyweight")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { hideKeyboard() }
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            value = (units.display(store.profile.bodyweight) * 10).rounded() / 10
        }
    }

    private func stats(_ log: [WeightEntry]) -> some View {
        let current = log.last?.kg ?? store.profile.bodyweight
        let monthAgo = Date().addingTimeInterval(-30 * 86400)
        let base = log.last(where: { $0.date <= monthAgo }) ?? log.first
        let change = base.map { current - $0.kg } ?? 0
        let sign = change > 0.05 ? "+" : ""
        return HStack(spacing: 10) {
            StatTile(value: store.weightText(current), label: "Current", symbol: "scalemass.fill", color: Theme.accent2)
            StatTile(value: "\(sign)\(fmtNumber(units.display(change))) \(units.rawValue)", label: "30-day change",
                     symbol: change >= 0 ? "arrow.up.right" : "arrow.down.right",
                     color: abs(change) < 0.05 ? Theme.textSecondary : (change > 0 ? Theme.warning : Theme.success))
            StatTile(value: "\(log.count)", label: "Weigh-ins", symbol: "calendar", color: Theme.accent)
        }
    }

    @ViewBuilder
    private func chart(_ log: [WeightEntry]) -> some View {
        if log.count >= 2 {
            let lo = log.map { units.display($0.kg) }.min() ?? 0
            let hi = log.map { units.display($0.kg) }.max() ?? 0
            VStack(alignment: .leading, spacing: 8) {
                Text("Trend (\(units.rawValue))").font(.caption).foregroundStyle(Theme.textSecondary)
                Chart(log) { e in
                    AreaMark(x: .value("Date", e.date), yStart: .value("Low", lo - 2), yEnd: .value("Weight", units.display(e.kg)))
                        .foregroundStyle(LinearGradient(colors: [Theme.accent2.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Date", e.date), y: .value("Weight", units.display(e.kg)))
                        .foregroundStyle(Theme.accentGradient)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", e.date), y: .value("Weight", units.display(e.kg)))
                        .foregroundStyle(Theme.accent2)
                        .symbolSize(24)
                }
                .chartYScale(domain: (lo - 2)...(hi + 2))
                .frame(height: 190)
            }
            .card()
        }
    }

    private var logCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Log a weigh-in").font(.headline)
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    NumberField(value: $value, placeholder: "0", font: .system(.title2, design: .rounded).weight(.bold))
                        .frame(width: 96, height: 46)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.08)))
                    Text(units.rawValue).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
                DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                    .labelsHidden()
            }
            PrimaryButton(title: "Save Weigh-in", symbol: "plus") {
                hideKeyboard()
                guard value > 0 else { return }
                withAnimation(Theme.spring) { store.logWeight(kg: units.toKg(value), date: date) }
                Haptics.success()
            }
        }
        .card()
    }

    @ViewBuilder
    private func history(_ log: [WeightEntry]) -> some View {
        if !log.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "History")
                VStack(spacing: 0) {
                    let rows = Array(log.reversed().prefix(60))
                    ForEach(Array(rows.enumerated()), id: \.element.id) { i, e in
                        HStack {
                            Text(e.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year()))
                                .font(.subheadline)
                            Spacer()
                            Text(store.weightText(e.kg)).font(.subheadline.weight(.bold))
                            Menu {
                                Button(role: .destructive) {
                                    withAnimation(Theme.spring) { store.deleteWeight(e.id) }
                                } label: { Label("Delete", systemImage: "trash") }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Theme.textTertiary)
                                    .frame(width: 30, height: 30)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        if i < rows.count - 1 { Divider().overlay(Theme.stroke) }
                    }
                }
                .card(padding: 0)
            }
        }
    }
}
