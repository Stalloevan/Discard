import SwiftUI

// Game Center (iOS 5/6 era) look: green felt, glossy bubbles, dark glass bars.

enum GC {
    static let feltDark = Color(red: 0.02, green: 0.17, blue: 0.10)
    static let feltLight = Color(red: 0.10, green: 0.40, blue: 0.24)
    static let gold = Color(red: 1.0, green: 0.82, blue: 0.32)
    static let blue = Color(red: 0.12, green: 0.45, blue: 0.90)
    static let dim = Color.white.opacity(0.7)
}

extension GameKind {
    var color: Color {
        switch self {
        case .hearts: return Color(red: 0.88, green: 0.20, blue: 0.25)
        case .cribbage: return Color(red: 0.90, green: 0.55, blue: 0.15)
        case .highLowJack: return Color(red: 0.55, green: 0.30, blue: 0.80)
        case .war: return Color(red: 0.45, green: 0.52, blue: 0.62)
        case .spades: return Color(red: 0.15, green: 0.40, blue: 0.85)
        case .ohHell: return Color(red: 0.92, green: 0.35, blue: 0.62)
        case .euchre: return Color(red: 0.10, green: 0.62, blue: 0.62)
        }
    }
}

struct FeltBackground: View {
    var body: some View {
        ZStack {
            RadialGradient(colors: [GC.feltLight, GC.feltDark], center: .top, startRadius: 20, endRadius: 760)
            Canvas { ctx, size in
                var x: CGFloat = -size.height
                while x < size.width {
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x + size.height, y: size.height))
                    ctx.stroke(p, with: .color(Color.black.opacity(0.06)), lineWidth: 1)
                    x += 4
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct Bubble<Content: View>: View {
    let color: Color
    let size: CGFloat
    let content: Content

    init(color: Color, size: CGFloat, @ViewBuilder content: () -> Content) {
        self.color = color
        self.size = size
        self.content = content()
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [color.opacity(0.7), color], startPoint: .top, endPoint: .bottom))
            Ellipse()
                .fill(LinearGradient(colors: [Color.white.opacity(0.7), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.7, height: size * 0.4)
                .offset(y: -size * 0.28)
            Circle()
                .stroke(Color.white.opacity(0.55), lineWidth: 1.2)
            content
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(0.45), radius: 4, x: 0, y: 3)
    }
}

struct GlossLabel: View {
    let configuration: ButtonStyleConfiguration
    let tint: Color
    let compact: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(compact ? .subheadline.bold() : .headline)
            .foregroundColor(.white)
            .padding(.horizontal, compact ? 12 : 18)
            .padding(.vertical, compact ? 6 : 9)
            .background(
                ZStack {
                    Capsule()
                        .fill(LinearGradient(colors: [tint.opacity(0.75), tint], startPoint: .top, endPoint: .bottom))
                    Capsule()
                        .fill(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.0)], startPoint: .top, endPoint: .center))
                    Capsule()
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                }
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1.0) : 0.4)
    }
}

struct GlossButtonStyle: ButtonStyle {
    var tint: Color = GC.blue
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        GlossLabel(configuration: configuration, tint: tint, compact: compact)
    }
}

struct Panel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.32)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.18), lineWidth: 1))
    }
}

extension View {
    func panel() -> some View {
        modifier(Panel())
    }

    func gcNavigation() -> some View {
        self
            .toolbarBackground(Color.black.opacity(0.85), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
