import WidgetKit
import SwiftUI

@main
struct AscendWidgetsBundle: WidgetBundle {
    var body: some Widget {
        AscendStatusWidget()
        WorkoutLiveActivity()
    }
}

// MARK: - Shared widget pieces

struct WidgetHexagon: Shape {
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

struct WidgetRankBadge: View {
    let colors: [Color]
    let symbol: String?
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            if let symbol, !colors.isEmpty {
                WidgetHexagon()
                    .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                WidgetHexagon()
                    .stroke(Color.white.opacity(0.45), style: StrokeStyle(lineWidth: max(1, size * 0.03), lineJoin: .round))
                    .padding(size * 0.09)
                Image(systemName: symbol)
                    .font(.system(size: size * 0.34, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                WidgetHexagon()
                    .stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                Image(systemName: "lock.fill")
                    .font(.system(size: size * 0.28, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.3))
            }
        }
        .frame(width: size, height: size * 1.1)
    }
}
