import SwiftUI

enum NeoLiquidPalette {
    static let voidBlack = Color(red: 0.02, green: 0.03, blue: 0.07)
    static let deepNavy = Color(red: 0.04, green: 0.07, blue: 0.14)
    static let auraCyan = Color(red: 0.34, green: 0.91, blue: 1.0)
    static let auraMint = Color(red: 0.47, green: 1.0, blue: 0.82)
    static let auraRose = Color(red: 1.0, green: 0.46, blue: 0.72)
    static let auraAmber = Color(red: 1.0, green: 0.73, blue: 0.33)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.72)
    static let textMuted = Color.white.opacity(0.46)
}

extension HostColorScheme {
    var liquidAccent: Color {
        switch self {
        case .ocean: return Color(red: 0.34, green: 0.82, blue: 1.0)
        case .forest: return Color(red: 0.47, green: 1.0, blue: 0.74)
        case .sunset: return Color(red: 1.0, green: 0.64, blue: 0.3)
        case .midnight: return Color(red: 0.73, green: 0.62, blue: 1.0)
        case .ruby: return Color(red: 1.0, green: 0.42, blue: 0.52)
        case .emerald: return Color(red: 0.44, green: 0.97, blue: 0.79)
        }
    }

    var glyphSymbol: String {
        switch self {
        case .ocean: return "dot.radiowaves.left.and.right"
        case .forest: return "leaf.circle"
        case .sunset: return "sun.max"
        case .midnight: return "sparkles"
        case .ruby: return "flame"
        case .emerald: return "atom"
        }
    }
}

struct NeoLiquidBackground: View {
    @State private var drifting = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [NeoLiquidPalette.voidBlack, NeoLiquidPalette.deepNavy, Color.black],
                startPoint: drifting ? .topLeading : .bottomTrailing,
                endPoint: drifting ? .bottomTrailing : .topLeading
            )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [NeoLiquidPalette.auraCyan.opacity(0.45), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 240
                    )
                )
                .frame(width: 440, height: 440)
                .offset(x: drifting ? -120 : 150, y: drifting ? -300 : -210)
                .blur(radius: 16)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [NeoLiquidPalette.auraRose.opacity(0.34), .clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 220
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: drifting ? 180 : -160, y: drifting ? 340 : 250)
                .blur(radius: 12)

            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.16))
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 14).repeatForever(autoreverses: true), value: drifting)
        .onAppear {
            drifting = true
        }
    }
}

struct NeoGlassCard<Content: View>: View {
    var accent: Color = NeoLiquidPalette.auraCyan
    var cornerRadius: CGFloat = 24
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        LinearGradient(
                            colors: [Color.white.opacity(0.24), Color.white.opacity(0.02), accent.opacity(0.16)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(accent.opacity(0.52), lineWidth: 1)
                    )
                    .shadow(color: accent.opacity(0.2), radius: 24, x: 0, y: 10)
            }
    }
}

struct NeoRoboGlyph: View {
    let symbol: String
    var accent: Color = NeoLiquidPalette.auraCyan
    var size: CGFloat = 54
    @State private var orbit = false

    var body: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.16))

            Circle()
                .stroke(accent.opacity(0.45), lineWidth: 1)

            Circle()
                .trim(from: 0.1, to: 0.76)
                .stroke(
                    AngularGradient(colors: [accent.opacity(0.1), accent, accent.opacity(0.1)], center: .center),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(orbit ? 360 : 0))

            Image(systemName: symbol)
                .font(.system(size: size * 0.38, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, accent)
        }
        .frame(width: size, height: size)
        .animation(.linear(duration: 7).repeatForever(autoreverses: false), value: orbit)
        .onAppear {
            orbit = true
        }
    }
}

struct NeoTagPill: View {
    let text: String
    var icon: String? = nil
    var accent: Color = NeoLiquidPalette.auraCyan

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(accent.opacity(0.28), in: Capsule())
        .overlay(
            Capsule()
                .stroke(accent.opacity(0.72), lineWidth: 0.8)
        )
    }
}

struct NeoLiquidButtonStyle: ButtonStyle {
    var tint: Color = NeoLiquidPalette.auraCyan
    var prominent: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(prominent ? tint.opacity(0.86) : Color.white.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(tint.opacity(0.7), lineWidth: 1)
                    )
            }
            .foregroundColor(.white)
            .shadow(color: tint.opacity(prominent ? 0.28 : 0.12), radius: 18, x: 0, y: 8)
            .animation(.spring(response: 0.2, dampingFraction: 0.85), value: configuration.isPressed)
    }
}

struct NeoSectionTitle: View {
    let title: String
    let subtitle: String
    var symbol: String
    var accent: Color

    var body: some View {
        HStack(spacing: 12) {
            NeoRoboGlyph(symbol: symbol, accent: accent, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(NeoLiquidPalette.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(NeoLiquidPalette.textMuted)
            }
            Spacer()
        }
    }
}

struct NeoInputSurface: ViewModifier {
    var accent: Color = NeoLiquidPalette.auraCyan

    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(accent.opacity(0.35), lineWidth: 1)
                    )
            )
            .foregroundColor(.white)
    }
}

extension View {
    func neoInputSurface(accent: Color = NeoLiquidPalette.auraCyan) -> some View {
        modifier(NeoInputSurface(accent: accent))
    }

    @ViewBuilder
    func liquidNavigationBackgroundHidden() -> some View {
        #if os(iOS)
        self.toolbarBackground(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}
