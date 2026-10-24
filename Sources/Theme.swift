import SwiftUI

// Look: flat green felt table, burgundy stitched leather, embossed serif lettering,
// rounded app-icon tiles. (Modernised from the original Game Center.)

enum GC {
    static let felt = Color(red: 0.23, green: 0.42, blue: 0.31)
    static let feltDark = Color(red: 0.12, green: 0.26, blue: 0.18)
    static let leather = Color(red: 0.50, green: 0.15, blue: 0.26)
    static let leatherDark = Color(red: 0.31, green: 0.08, blue: 0.16)
    static let button = Color(red: 0.60, green: 0.19, blue: 0.32)
    static let gold = Color(red: 0.96, green: 0.80, blue: 0.46)
    static let cream = Color(red: 0.97, green: 0.94, blue: 0.86)
    static let dim = Color.white.opacity(0.68)
}

extension GameKind {
    var color: Color {
        switch self {
        case .hearts: return Color(red: 0.86, green: 0.22, blue: 0.27)
        case .cribbage: return Color(red: 0.88, green: 0.56, blue: 0.18)
        case .highLowJack: return Color(red: 0.56, green: 0.33, blue: 0.80)
        case .war: return Color(red: 0.42, green: 0.50, blue: 0.60)
        case .spades: return Color(red: 0.16, green: 0.40, blue: 0.84)
        case .ohHell: return Color(red: 0.90, green: 0.36, blue: 0.60)
        case .euchre: return Color(red: 0.12, green: 0.60, blue: 0.58)
        }
    }

    var playersText: String {
        return "\(minPlayers)–8 players"
    }
}

struct FeltBackground: View {
    var body: some View {
        ZStack {
            RadialGradient(colors: [GC.felt, GC.feltDark], center: .top, startRadius: 40, endRadius: 800)
            Canvas { ctx, size in
                var x: CGFloat = -size.height
                while x < size.width {
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x + size.height, y: size.height))
                    ctx.stroke(p, with: .color(Color.black.opacity(0.05)), lineWidth: 1)
                    var q = Path()
                    q.move(to: CGPoint(x: x + size.height, y: 0))
                    q.addLine(to: CGPoint(x: x, y: size.height))
                    ctx.stroke(q, with: .color(Color.white.opacity(0.025)), lineWidth: 1)
                    x += 3
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// Burgundy leather with a stitched gold border.
struct LeatherBackground: View {
    var corner: CGFloat = 16

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner)
                .fill(LinearGradient(colors: [GC.leather, GC.leatherDark], startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: corner)
                .fill(RadialGradient(colors: [Color.white.opacity(0.14), Color.clear], center: .top, startRadius: 0, endRadius: 240))
            RoundedRectangle(cornerRadius: corner)
                .stroke(Color.black.opacity(0.55), lineWidth: 1)
            RoundedRectangle(cornerRadius: max(corner - 5, 2))
                .inset(by: 5)
                .strokeBorder(GC.gold.opacity(0.6), style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))
        }
        .shadow(color: Color.black.opacity(0.4), radius: 5, x: 0, y: 3)
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
            .padding(.vertical, compact ? 6 : 10)
            .background(
                ZStack {
                    Capsule()
                        .fill(LinearGradient(colors: [tint.opacity(0.9), tint.opacity(0.65)], startPoint: .top, endPoint: .bottom))
                    Capsule()
                        .fill(LinearGradient(colors: [Color.white.opacity(0.28), Color.white.opacity(0.0)], startPoint: .top, endPoint: .center))
                    Capsule()
                        .inset(by: 3)
                        .strokeBorder(GC.gold.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    Capsule()
                        .stroke(Color.black.opacity(0.45), lineWidth: 1)
                }
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1.0) : 0.4)
    }
}

struct GlossButtonStyle: ButtonStyle {
    var tint: Color = GC.button
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        GlossLabel(configuration: configuration, tint: tint, compact: compact)
    }
}

/// Rounded app-icon tile, like the game icons in the reference.
struct GameTile: View {
    let kind: GameKind
    var size: CGFloat = 78

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(LinearGradient(colors: [kind.color.opacity(0.85), kind.color.opacity(0.95)], startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(LinearGradient(colors: [Color.white.opacity(0.38), Color.white.opacity(0.0)], startPoint: .top, endPoint: .center))
            RoundedRectangle(cornerRadius: size * 0.22)
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
            Image(systemName: kind.symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.35), radius: 1, x: 0, y: 1)
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(0.45), radius: 4, x: 0, y: 3)
    }
}

/// Four-suit logo in the style of the Game Center icon.
struct LogoTile: View {
    var size: CGFloat = 64

    private func quad(_ symbol: String, _ color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.1)
                .fill(LinearGradient(colors: [color.opacity(0.9), color], startPoint: .top, endPoint: .bottom))
            Image(systemName: symbol)
                .font(.system(size: size * 0.24, weight: .bold))
                .foregroundColor(.white)
        }
    }

    var body: some View {
        VStack(spacing: size * 0.04) {
            HStack(spacing: size * 0.04) {
                quad("suit.spade.fill", Color(red: 0.16, green: 0.40, blue: 0.84))
                quad("suit.heart.fill", Color(red: 0.86, green: 0.22, blue: 0.27))
            }
            HStack(spacing: size * 0.04) {
                quad("suit.club.fill", Color(red: 0.20, green: 0.62, blue: 0.32))
                quad("suit.diamond.fill", Color(red: 0.92, green: 0.60, blue: 0.16))
            }
        }
        .padding(size * 0.06)
        .frame(width: size, height: size)
        .background(RoundedRectangle(cornerRadius: size * 0.22).fill(Color(white: 0.95)))
        .shadow(color: Color.black.opacity(0.4), radius: 3, x: 0, y: 2)
    }
}

struct Embossed: ViewModifier {
    var size: CGFloat
    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .heavy, design: .serif))
            .tracking(1.5)
            .foregroundColor(.white)
            .shadow(color: Color.black.opacity(0.55), radius: 0, x: 0, y: 2)
    }
}

struct Panel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.24)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.14), lineWidth: 1))
    }
}

extension View {
    func panel() -> some View {
        modifier(Panel())
    }

    func leather(corner: CGFloat = 16) -> some View {
        self
            .padding(12)
            .background(LeatherBackground(corner: corner))
    }

    func embossed(_ size: CGFloat) -> some View {
        modifier(Embossed(size: size))
    }

    func gcNavigation() -> some View {
        self
            .toolbarBackground(GC.feltDark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }

    func gcTitle(_ title: String) -> some View {
        self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title.uppercased())
                        .font(.system(size: 17, weight: .heavy, design: .serif))
                        .tracking(1.5)
                        .foregroundColor(.white)
                }
            }
    }
}

/// Tap-to-choose chips (used for "who called trump", results and so on).
struct ChoiceChips: View {
    let items: [String]
    @Binding var selection: Int
    var columns: Int = 4

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: max(1, min(columns, items.count))), spacing: 6) {
            ForEach(0..<items.count, id: \.self) { i in
                Text(items[i])
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(i == selection ? GC.button : Color.black.opacity(0.28))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(i == selection ? GC.gold : Color.white.opacity(0.15), lineWidth: i == selection ? 2 : 1)
                    )
                    .onTapGesture {
                        selection = i
                    }
            }
        }
    }
}
