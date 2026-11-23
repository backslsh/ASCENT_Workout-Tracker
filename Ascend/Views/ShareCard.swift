import SwiftUI

/// A 9:16 card rendered to an image for Instagram stories, iMessage, etc.
struct RankShareCard: View {
    let title: String
    let subtitle: String
    let rank: RankInfo?
    let name: String
    var stats: [(String, String)] = []

    var signature: String {
        "\(title)|\(subtitle)|\(rank?.title ?? "-")|\(name)|\(stats.map { $0.0 + $0.1 }.joined())|\(ThemeManager.shared.theme.rawValue)"
    }

    var body: some View {
        let colors = rank?.tier.colors ?? [Theme.accent, Theme.accent2]
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.up.2").font(.system(size: 14, weight: .black))
                    Text("ASCEND").font(.system(size: 15, weight: .heavy, design: .rounded)).tracking(3)
                }
                .foregroundStyle(Theme.accentGradient)
                Spacer()
                Text(Date().formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            Spacer()
            ZStack {
                Circle().fill(colors[0].opacity(0.35)).frame(width: 230, height: 230).blur(radius: 50)
                RankBadge(rank: rank, size: 160)
            }
            Text(rank?.title ?? "Unranked")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.top, 18)
            Text(title.uppercased())
                .font(.system(size: 15, weight: .heavy))
                .tracking(2)
                .foregroundStyle(.white)
                .padding(.top, 6)
            Text(subtitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.6))
                .padding(.top, 4)
            if !stats.isEmpty {
                HStack(spacing: 10) {
                    ForEach(Array(stats.enumerated()), id: \.offset) { _, s in
                        VStack(spacing: 2) {
                            Text(s.0).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(.white)
                            Text(s.1).font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.07)))
                    }
                }
                .padding(.top, 24)
            }
            Spacer()
            Text(name.isEmpty ? "Ranked on Ascend" : "\(name) · ranked on Ascend")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.45))
        }
        .padding(28)
        .frame(width: 360, height: 640)
        .background {
            ZStack {
                Color(hex: 0x07070A)
                RadialGradient(colors: [colors[0].opacity(0.30), .clear], center: .top, startRadius: 0, endRadius: 420)
                RadialGradient(colors: [Theme.accent.opacity(0.22), .clear], center: .bottomLeading, startRadius: 0, endRadius: 380)
                RadialGradient(colors: [Theme.accent2.opacity(0.14), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 380)
            }
        }
        .environment(\.colorScheme, .dark)
    }
}

/// Renders the card off-screen and offers it through the system share sheet.
struct ShareRankButton: View {
    let card: RankShareCard
    var glass: Bool = true
    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                ShareLink(item: image, preview: SharePreview("\(card.title) rank", image: image)) { icon }
                    .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
            } else {
                icon.opacity(0.4)
            }
        }
        .onAppear { render() }
        .onChange(of: card.signature) { _, _ in render() }
    }

    @ViewBuilder
    private var icon: some View {
        let symbol = Image(systemName: "square.and.arrow.up")
        if glass {
            symbol
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .liquidGlass(Circle(), interactive: true)
        } else {
            symbol.fontWeight(.semibold)
        }
    }

    @MainActor private func render() {
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        if let ui = renderer.uiImage { image = Image(uiImage: ui) }
    }
}
