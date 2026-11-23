import SwiftUI

struct PlateCalculatorView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let initialKg: Double
    var onApply: ((Double) -> Void)? = nil

    @State private var target: Double = 0
    @State private var loaded = false

    private var units: UnitSystem { store.profile.units }
    private var plates: [Double] { units == .lb ? [45, 35, 25, 10, 5, 2.5] : [25, 20, 15, 10, 5, 2.5, 1.25] }
    private var barOptions: [Double] { units == .lb ? [45, 35, 15] : [20, 15, 10] }
    private var step: Double { units == .lb ? 5 : 2.5 }

    private var bar: Double {
        guard let kg = store.profile.barKg else { return barOptions[0] }
        let v = (units.display(kg) * 2).rounded() / 2
        return barOptions.first { abs($0 - v) < 0.01 } ?? barOptions[0]
    }

    private var barBinding: Binding<Double> {
        Binding(get: { bar }, set: { store.profile.barKg = units.toKg($0) })
    }

    private var result: (plates: [Double], remainder: Double) {
        var side = max(0, (target - bar) / 2)
        var out: [Double] = []
        for p in plates {
            while side + 1e-6 >= p {
                out.append(p)
                side -= p
            }
        }
        return (out, max(0, side * 2))
    }

    var body: some View {
        let r = result
        let loadable = max(bar, target - r.remainder)
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    targetCard
                    BarbellView(plates: r.plates, units: units)
                        .frame(height: 150)
                        .frame(maxWidth: .infinity)
                        .card(padding: 12)
                    breakdown(r, loadable: loadable)
                    Picker("Bar", selection: barBinding) {
                        ForEach(barOptions, id: \.self) { b in
                            Text("\(fmtNumber(b)) \(units.rawValue) bar").tag(b)
                        }
                    }
                    .pickerStyle(.segmented)
                    if let onApply {
                        PrimaryButton(title: "Use \(fmtNumber(loadable)) \(units.rawValue)", symbol: "checkmark") {
                            onApply(units.toKg(loadable))
                            dismiss()
                        }
                    }
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
            .background(AppBackground())
            .navigationTitle("Plate Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.bold) }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            let shown = (units.display(initialKg) * 2).rounded() / 2
            target = shown > 0 ? shown : bar + 2 * plates[0]
        }
    }

    private var targetCard: some View {
        VStack(spacing: 6) {
            Text("TARGET WEIGHT").font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(Theme.textTertiary)
            HStack(spacing: 14) {
                stepButton("minus") { target = max(bar, target - step) }
                VStack(spacing: 0) {
                    NumberField(value: $target, placeholder: "0",
                                font: .system(size: 40, weight: .heavy, design: .rounded))
                        .frame(height: 52)
                    Text(units.rawValue).font(.caption.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                }
                stepButton("plus") { target += step }
            }
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    private func stepButton(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            hideKeyboard()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .liquidGlass(Circle(), interactive: true)
        }
        .buttonStyle(.pressable)
    }

    private func breakdown(_ r: (plates: [Double], remainder: Double), loadable: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Each side").font(.headline)
                Spacer()
                Text(r.plates.isEmpty ? "Just the bar" : grouped(r.plates))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.accent2)
                    .multilineTextAlignment(.trailing)
            }
            if r.remainder > 0.01 {
                Label("Closest you can load is \(fmtNumber(loadable)) \(units.rawValue)", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.warning)
            }
            if target < bar {
                Label("That's lighter than the bar", systemImage: "info.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .card()
    }

    /// [45, 45, 10] -> "45 ×2 · 10"
    private func grouped(_ p: [Double]) -> String {
        var parts: [String] = []
        var i = 0
        while i < p.count {
            var j = i
            while j + 1 < p.count && p[j + 1] == p[i] { j += 1 }
            let n = j - i + 1
            parts.append(n > 1 ? "\(fmtNumber(p[i])) ×\(n)" : fmtNumber(p[i]))
            i = j + 1
        }
        return parts.joined(separator: " · ")
    }
}

struct BarbellView: View {
    let plates: [Double]
    let units: UnitSystem

    private var maxPlate: Double { units == .lb ? 45 : 25 }

    var body: some View {
        HStack(spacing: 2) {
            sleeveTip
            ForEach(Array(plates.reversed().enumerated()), id: \.offset) { _, p in plate(p) }
            collar
            RoundedRectangle(cornerRadius: 2).fill(steel).frame(width: 70, height: 9)
            collar
            ForEach(Array(plates.enumerated()), id: \.offset) { _, p in plate(p) }
            sleeveTip
        }
        .animation(Theme.spring, value: plates)
    }

    private var steel: LinearGradient {
        LinearGradient(colors: [Color(hex: 0xC9CED6), Color(hex: 0x6F7680)], startPoint: .top, endPoint: .bottom)
    }

    private var collar: some View {
        RoundedRectangle(cornerRadius: 2).fill(steel).frame(width: 8, height: 26)
    }

    private var sleeveTip: some View {
        RoundedRectangle(cornerRadius: 2).fill(steel).frame(width: 12, height: 14)
    }

    private func plate(_ p: Double) -> some View {
        let big = p >= maxPlate * 0.5
        return RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(LinearGradient(colors: [color(p), color(p).opacity(0.7)], startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
            .frame(width: big ? 13 : 9, height: 44 + 90 * sqrt(p / maxPlate))
            .transition(.scale.combined(with: .opacity))
    }

    private func color(_ p: Double) -> Color {
        if units == .lb {
            switch p {
            case 45: return Color(hex: 0x3D6BFF)
            case 35: return Color(hex: 0xFFD84D)
            case 25: return Color(hex: 0x3DDC97)
            case 10: return Color(hex: 0xE6ECF2)
            case 5: return Color(hex: 0xFF5D6C)
            default: return Color(hex: 0x9AA0A9)
            }
        }
        switch p {
        case 25: return Color(hex: 0xFF5D6C)
        case 20: return Color(hex: 0x3D6BFF)
        case 15: return Color(hex: 0xFFD84D)
        case 10: return Color(hex: 0x3DDC97)
        case 5: return Color(hex: 0xE6ECF2)
        case 2.5: return Color(hex: 0xFF8A65)
        default: return Color(hex: 0x9AA0A9)
        }
    }
}
