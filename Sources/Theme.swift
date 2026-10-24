import SwiftUI

// Flat Catppuccin Latte. No gradients, no shadows.
// Leather elements use a real CC0 leather photo (Poly Haven), tinted to Rosewater at build time.

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}

enum GC {
    // Latte neutrals
    static let base = Color(hex: 0xEFF1F5)
    static let mantle = Color(hex: 0xE6E9EF)
    static let crust = Color(hex: 0xDCE0E8)
    static let surface0 = Color(hex: 0xCCD0DA)
    static let surface1 = Color(hex: 0xBCC0CC)
    static let overlay = Color(hex: 0x9CA0B0)
    static let text = Color(hex: 0x4C4F69)
    static let dim = Color(hex: 0x6C6F85)

    // Latte accents
    static let rosewater = Color(hex: 0xDC8A78)
    static let red = Color(hex: 0xD20F39)
    static let green = Color(hex: 0x40A02B)
    static let yellow = Color(hex: 0xDF8E1D)
    static let blue = Color(hex: 0x1E66F5)

    // Roles
    static let button = rosewater
    static let gold = yellow
    static let cream = base
    static let leatherFallback = Color(hex: 0xB26C5E)
    static let onLeather = base
    static let onLeatherDim = Color(hex: 0xEFF1F5).opacity(0.8)
}

extension GameKind {
    var color: Color {
        switch self {
        case .hearts: return Color(hex: 0xD20F39)
        case .cribbage: return Color(hex: 0xFE640B)
        case .highLowJack: return Color(hex: 0x8839EF)
        case .war: return Color(hex: 0x7287FD)
        case .spades: return Color(hex: 0x1E66F5)
        case .ohHell: return Color(hex: 0xEA76CB)
        case .euchre: return Color(hex: 0x179299)
        }
    }

    var playersText: String {
        return "\(minPlayers)–8 players"
    }
}

struct FeltBackground: View {
    var body: some View {
        GC.base.ignoresSafeArea()
    }
}

/// Rosewater leather: the tinted photo texture with flat stitching.
struct LeatherBackground: View {
    var corner: CGFloat = 16

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner)
                .fill(GC.leatherFallback)
            Image("Leather")
                .resizable(resizingMode: .tile)
                .clipShape(RoundedRectangle(cornerRadius: corner))
            RoundedRectangle(cornerRadius: max(corner - 5, 2))
                .inset(by: 5)
                .strokeBorder(GC.onLeather.opacity(0.75), style: StrokeStyle(lineWidth: 1.3, dash: [5, 3]))
        }
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
            .foregroundColor(GC.text)
            .padding(.horizontal, compact ? 12 : 18)
            .padding(.vertical, compact ? 6 : 10)
            .background(Capsule().fill(tint))
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1.0) : 0.4)
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
                .fill(kind.color)
            Image(systemName: kind.symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundColor(GC.base)
        }
        .frame(width: size, height: size)
    }
}

/// Four-suit logo in the style of the Game Center icon.
struct LogoTile: View {
    var size: CGFloat = 64

    private func quad(_ symbol: String, _ color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.1)
                .fill(color)
            Image(systemName: symbol)
                .font(.system(size: size * 0.24, weight: .bold))
                .foregroundColor(GC.base)
        }
    }

    var body: some View {
        VStack(spacing: size * 0.04) {
            HStack(spacing: size * 0.04) {
                quad("suit.spade.fill", Color(hex: 0x1E66F5))
                quad("suit.heart.fill", Color(hex: 0xD20F39))
            }
            HStack(spacing: size * 0.04) {
                quad("suit.club.fill", Color(hex: 0x40A02B))
                quad("suit.diamond.fill", Color(hex: 0xDF8E1D))
            }
        }
        .padding(size * 0.06)
        .frame(width: size, height: size)
        .background(RoundedRectangle(cornerRadius: size * 0.22).fill(GC.base))
    }
}

/// Serif lettering used on the leather banners.
struct Embossed: ViewModifier {
    var size: CGFloat
    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .heavy, design: .serif))
            .tracking(1.5)
            .foregroundColor(GC.onLeather)
    }
}

struct Panel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 14).fill(GC.mantle))
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
            .toolbarBackground(GC.mantle, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .tint(GC.rosewater)
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
                        .foregroundColor(GC.text)
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
                    .foregroundColor(GC.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(i == selection ? GC.rosewater : GC.surface0)
                    )
                    .onTapGesture {
                        selection = i
                    }
            }
        }
    }
}
