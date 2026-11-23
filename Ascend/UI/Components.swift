import SwiftUI

struct ExerciseRoute: Hashable { let id: String }

// MARK: - Muscle icon

struct MuscleIcon: View {
    let group: MuscleGroup
    var size: CGFloat = 38
    var body: some View {
        Image(systemName: group.symbol)
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundStyle(group.color)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous).fill(group.color.opacity(0.15)))
            .overlay(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous).strokeBorder(group.color.opacity(0.25), lineWidth: 1))
    }
}

struct MuscleStack: View {
    let groups: [MuscleGroup]
    var size: CGFloat = 26
    var body: some View {
        HStack(spacing: -size * 0.25) {
            ForEach(Array(groups.prefix(4)), id: \.self) { g in
                MuscleIcon(group: g, size: size)
                    .background(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous).fill(Theme.surface))
            }
            if groups.count > 4 {
                Text("+\(groups.count - 4)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.leading, size * 0.35)
            }
        }
    }
}

// MARK: - Rank badge

struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let pts = [
            CGPoint(x: w * 0.5, y: 0), CGPoint(x: w, y: h * 0.25), CGPoint(x: w, y: h * 0.75),
            CGPoint(x: w * 0.5, y: h), CGPoint(x: 0, y: h * 0.75), CGPoint(x: 0, y: h * 0.25),
        ].map { CGPoint(x: $0.x + rect.minX, y: $0.y + rect.minY) }
        var p = Path()
        p.addLines(pts)
        p.closeSubpath()
        return p
    }
}

struct RankBadge: View {
    let rank: RankInfo?
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            if let rank {
                Hexagon()
                    .fill(LinearGradient(colors: rank.tier.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: rank.tier.glows ? rank.color.opacity(0.55) : .clear, radius: size * 0.22)
                Hexagon()
                    .stroke(Color.white.opacity(0.45), style: StrokeStyle(lineWidth: max(1, size * 0.03), lineJoin: .round))
                    .padding(size * 0.09)
                VStack(spacing: size * 0.05) {
                    Image(systemName: rank.tier.symbol)
                        .font(.system(size: size * 0.32, weight: .bold))
                    if rank.division > 0 && size >= 30 {
                        HStack(spacing: size * 0.05) {
                            ForEach(0..<(4 - rank.division), id: \.self) { _ in
                                Circle().frame(width: size * 0.07, height: size * 0.07)
                            }
                        }
                    }
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
            } else {
                Hexagon()
                    .stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: max(1, size * 0.035), dash: [size * 0.08, size * 0.06]))
                Image(systemName: "lock.fill")
                    .font(.system(size: size * 0.26, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.25))
            }
        }
        .frame(width: size, height: size * 1.1)
    }
}

// MARK: - Progress bar

struct ProgressBar: View {
    var value: Double
    var colors: [Color] = [Theme.accent, Theme.accent2]
    var height: CGFloat = 6
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(height, geo.size.width * min(max(value, 0), 1)))
            }
        }
        .frame(height: height)
        .animation(Theme.spring, value: value)
    }
}

// MARK: - Headers

struct ScreenHeader<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                if let subtitle {
                    Text(subtitle.uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.textTertiary)
                }
                Text(title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
            }
            Spacer()
            trailing()
        }
        .padding(.top, 8)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle, trailing: { EmptyView() })
    }
}

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        HStack {
            Text(title).font(.title3.weight(.bold))
            Spacer()
            if let actionTitle, let action {
                Button {
                    Haptics.tap()
                    action()
                } label: {
                    Text(actionTitle).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                }
            }
        }
    }
}

// MARK: - Buttons

struct GlassIconButton: View {
    let symbol: String
    var tint: Color = .white
    var size: CGFloat = 42
    let action: () -> Void
    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .liquidGlass(Circle(), interactive: true)
        }
        .buttonStyle(.pressable)
    }
}

struct PrimaryButton: View {
    let title: String
    var symbol: String? = nil
    let action: () -> Void
    var body: some View {
        Button {
            Haptics.medium()
            action()
        } label: {
            HStack(spacing: 8) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Capsule().fill(Theme.accentGradient))
            .shadow(color: Theme.accent.opacity(0.4), radius: 16, y: 6)
        }
        .buttonStyle(.pressable)
    }
}

struct SecondaryButton: View {
    let title: String
    var symbol: String? = nil
    var tint: Color = .white
    let action: () -> Void
    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 8) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
            }
            .font(.headline)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .liquidGlass(Capsule(), interactive: true)
        }
        .buttonStyle(.pressable)
    }
}

// MARK: - Small pieces

struct StatTile: View {
    let value: String
    let label: String
    var symbol: String? = nil
    var color: Color = Theme.accent
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let symbol {
                Image(systemName: symbol).font(.subheadline.weight(.semibold)).foregroundStyle(color)
            }
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            Text(label).font(.caption).foregroundStyle(Theme.textSecondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14, radius: 18)
    }
}

struct Chip: View {
    let title: String
    var color: Color = Theme.accent
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? Color.black : Color.white.opacity(0.85))
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(Capsule().fill(selected ? color : Color.white.opacity(0.07)))
        }
        .buttonStyle(.pressable)
    }
}

struct InfoPill: View {
    let symbol: String
    let text: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.caption2)
            Text(text).font(.caption.weight(.semibold))
        }
        .foregroundStyle(Theme.textSecondary)
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(Capsule().fill(Color.white.opacity(0.06)))
    }
}

struct Avatar: View {
    let name: String
    var size: CGFloat = 64
    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let s = parts.compactMap { $0.first }.map(String.init).joined()
        return s.isEmpty ? "A" : s.uppercased()
    }
    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(Theme.accentGradient))
            .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1.5))
            .shadow(color: Theme.accent.opacity(0.35), radius: 12, y: 4)
    }
}

struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Theme.accentGradient)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .card()
    }
}

// MARK: - Number input

struct NumberField: View {
    @Binding var value: Double
    var placeholder: String = "0"
    var decimals: Bool = true
    var font: Font = .system(.body, design: .rounded).weight(.semibold)
    @State private var text: String = ""
    @FocusState private var focused: Bool

    static func format(_ v: Double) -> String { v == 0 ? "" : fmtNumber(v) }

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(decimals ? .decimalPad : .numberPad)
            .multilineTextAlignment(.center)
            .font(font)
            .focused($focused)
            .onAppear { text = Self.format(value) }
            .onChange(of: text) { _, new in
                let cleaned = new.replacingOccurrences(of: ",", with: ".")
                if let v = Double(cleaned) {
                    if abs(v - value) > 0.0001 { value = v }
                } else if cleaned.isEmpty, value != 0 {
                    value = 0
                }
            }
            .onChange(of: value) { _, new in
                if !focused { text = Self.format(new) }
            }
            .onChange(of: focused) { _, isFocused in
                if !isFocused { text = Self.format(value) }
            }
    }
}

// MARK: - Confetti

struct ConfettiView: View {
    struct Particle {
        let x: Double, delay: Double, speed: Double, spin: Double, size: Double, drift: Double
        let color: Color
    }

    @State private var start = Date()
    @State private var finished = false
    @State private var particles: [Particle] = (0..<90).map { _ in
        Particle(x: .random(in: 0...1), delay: .random(in: 0...0.6), speed: .random(in: 0.3...0.6),
                 spin: .random(in: -6...6), size: .random(in: 6...11), drift: .random(in: -30...30),
                 color: [Theme.accent, Theme.accent2, Theme.success, RankTier.gold.colors[0], MuscleGroup.chest.color].randomElement() ?? .white)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: finished)) { ctx in
            Canvas { gc, size in
                let t = ctx.date.timeIntervalSince(start)
                for p in particles {
                    let lt = t - p.delay
                    guard lt > 0 else { continue }
                    let y = -20 + lt * p.speed * size.height
                    guard y < size.height + 20 else { continue }
                    let x = p.x * size.width + sin(lt * 3 + p.spin) * p.drift
                    var g = gc
                    g.translateBy(x: x, y: y)
                    g.rotate(by: .radians(lt * p.spin))
                    g.opacity = max(0, 1 - lt / 3.5)
                    let r = CGRect(x: -p.size / 2, y: -p.size / 4, width: p.size, height: p.size / 2)
                    g.fill(Path(roundedRect: r, cornerRadius: 1.5), with: .color(p.color))
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) { finished = true }
        }
    }
}

// MARK: - Layout helpers

enum CardMode { case live, plan }

extension View {
    @ViewBuilder
    func column(_ mode: CardMode, width: CGFloat) -> some View {
        if mode == .live { self.frame(width: width) } else { self.frame(maxWidth: .infinity) }
    }

    func fieldStyle(done: Bool) -> some View {
        self.frame(height: 36)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(done ? 0.04 : 0.08)))
    }
}
