import SwiftUI
import UIKit
import Observation
import AudioToolbox

/// The selected accent palette. `@Observable`, so every view that reads `Theme.accent`
/// re-renders automatically when the user picks a new theme.
@Observable
final class ThemeManager {
    var theme: AccentTheme = .aurora
}

extension ThemeManager {
    static let shared = ThemeManager()
}

enum Theme {
    static let bg = Color(hex: 0x07070A)
    static let surface = Color(hex: 0x131318)
    static let surface2 = Color(hex: 0x1C1C23)
    static let stroke = Color.white.opacity(0.07)
    static var accent: Color { ThemeManager.shared.theme.accent }
    static var accent2: Color { ThemeManager.shared.theme.accent2 }
    static let success = Color(hex: 0x4BE3A0)
    static let warning = Color(hex: 0xFFB547)
    static let danger = Color(hex: 0xFF5D6C)
    static let textSecondary = Color.white.opacity(0.6)
    static let textTertiary = Color.white.opacity(0.38)

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let spring = Animation.spring(response: 0.38, dampingFraction: 0.82)
    static let snappy = Animation.spring(response: 0.26, dampingFraction: 0.86)
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            Theme.bg
            RadialGradient(colors: [Theme.accent.opacity(0.16), .clear], center: .topLeading, startRadius: 0, endRadius: 440)
            RadialGradient(colors: [Theme.accent2.opacity(0.08), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 500)
        }
        .ignoresSafeArea()
    }
}

struct CardModifier: ViewModifier {
    var padding: CGFloat
    var radius: CGFloat
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Theme.surface.opacity(0.92)))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
    }
}

extension View {
    func card(padding: CGFloat = 16, radius: CGFloat = 22) -> some View {
        modifier(CardModifier(padding: padding, radius: radius))
    }
}

// MARK: - Liquid Glass (real iOS 26 glass when available, material fallback otherwise)

extension View {
    @ViewBuilder
    func liquidGlass<S: Shape>(_ shape: S, interactive: Bool = false, tint: Color? = nil) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(GlassFactory.make(interactive: interactive, tint: tint), in: shape)
        } else {
            self.modifier(FallbackGlass(shape: shape, tint: tint))
        }
        #else
        self.modifier(FallbackGlass(shape: shape, tint: tint))
        #endif
    }
}

#if compiler(>=6.2)
@available(iOS 26.0, *)
enum GlassFactory {
    static func make(interactive: Bool, tint: Color?) -> Glass {
        var g: Glass = .regular
        if let tint { g = g.tint(tint) }
        if interactive { g = g.interactive() }
        return g
    }
}
#endif

struct FallbackGlass<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color?
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    if let tint { shape.fill(tint) }
                    shape.fill(LinearGradient(colors: [Color.white.opacity(0.10), .clear], startPoint: .top, endPoint: .bottom))
                }
            }
            .overlay(shape.stroke(Color.white.opacity(0.14), lineWidth: 0.75))
    }
}

// MARK: - Buttons

struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
}

// MARK: - Haptics

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func select() { UISelectionFeedbackGenerator().selectionChanged() }
}

// MARK: - Sound effects (built-in iOS system sounds; they respect the silent switch)

enum Sounds {
    static var enabled = true

    private static func play(_ id: SystemSoundID) {
        guard enabled else { return }
        AudioServicesPlaySystemSound(id)
    }

    static func setDone() { play(1104) }
    static func restDone() { play(1007) }
    static func pr() { play(1025) }
    static func rankUp() { play(1025) }
    static func finish() { play(1001) }
}
