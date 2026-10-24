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
    static let leatherBase = Color(hex: 0xB26C5E)
    static let stitch = Color(hex: 0xDF8E1D)
    static let onLeather = base
    static let onLeatherDim = Color(hex: 0xEFF1F5).opacity(0.85)

    // The green table
    static let felt = Color(hex: 0x3B6B4F)
    static let feltDark = Color(hex: 0x2E5640)
    static let onFelt = base
    static let onFeltDim = Color(hex: 0xEFF1F5).opacity(0.75)
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

/// Flat green with a fine, fixed grain of noise.
struct FeltBackground: View {
    var body: some View {
        ZStack {
            GC.felt
            Canvas { ctx, size in
                var seed: UInt64 = 88172645463325252
                let count = Int(size.width * size.height / 14)
                for _ in 0..<count {
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    let a = Double((seed >> 33) & 0xFFFF) / 65535.0
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    let b = Double((seed >> 33) & 0xFFFF) / 65535.0
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    let c = Double((seed >> 33) & 0xFF) / 255.0
                    let rect = CGRect(x: a * size.width, y: b * size.height, width: 1.2, height: 1.2)
                    let tone: Color = c < 0.5 ? Color.black : Color.white
                    ctx.fill(Path(rect), with: .color(tone.opacity(0.05 + 0.05 * c)))
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// Rosewater leather: the photo at 25% over solid leather, with flat yellow stitching.
struct LeatherBackground: View {
    var corner: CGFloat = 16

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner)
                .fill(GC.leatherBase)
            Image("Leather")
                .resizable(resizingMode: .tile)
                .opacity(0.25)
                .clipShape(RoundedRectangle(cornerRadius: corner))
            RoundedRectangle(cornerRadius: max(corner - 5, 2))
                .inset(by: 5)
                .strokeBorder(GC.stitch, style: StrokeStyle(lineWidth: 1.6, dash: [5, 3]))
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

    /// We draw our own header, so the system bar (and its glass buttons) stays out of the way.
    func gcNavigation() -> some View {
        self
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
    }
}

extension UINavigationController: UIGestureRecognizerDelegate {
    open override func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }
}

/// Flat leather bar with yellow stitching along its lower edge. Runs up behind the status bar.
struct LeatherBar: View {
    var body: some View {
        ZStack {
            GC.leatherBase
            Image("Leather")
                .resizable(resizingMode: .tile)
                .opacity(0.25)
            GeometryReader { geo in
                Path { path in
                    path.move(to: CGPoint(x: 8, y: geo.size.height - 5))
                    path.addLine(to: CGPoint(x: geo.size.width - 8, y: geo.size.height - 5))
                }
                .stroke(GC.stitch, style: StrokeStyle(lineWidth: 1.6, dash: [5, 3]))
            }
        }
    }
}

/// The header: leather bar, app icon, title, back button and trailing buttons.
struct GCHeader<Trailing: View>: View {
    let title: String
    var showBack: Bool
    let trailing: Trailing
    var below: AnyView? = nil
    var kind: GameKind? = nil
    var edgePad: EdgeInsets = EdgeInsets()
    @Environment(\.dismiss) private var dismiss

    /// Extra padding where the screen's own safe area ends up after the whole UI is turned.
    func insets(_ i: EdgeInsets) -> GCHeader {
        var copy = self
        copy.edgePad = i
        return copy
    }

    /// Show this game's icon instead of the app icon.
    func icon(_ k: GameKind) -> GCHeader {
        var copy = self
        copy.kind = k
        return copy
    }

    init(_ title: String, showBack: Bool = true, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.showBack = showBack
        self.trailing = trailing()
    }

    /// Header with extra content (the scores) built into the leather under the title row.
    init<B: View>(_ title: String, showBack: Bool = true, @ViewBuilder trailing: () -> Trailing, @ViewBuilder below: () -> B) {
        self.title = title
        self.showBack = showBack
        self.trailing = trailing()
        self.below = AnyView(below())
    }

    var body: some View {
        VStack(spacing: 6) {
        HStack(spacing: 10) {
            if showBack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(GC.onLeather)
                        .frame(width: 32, height: 36)
                }
                .buttonStyle(.plain)
            }
            if let k = kind {
                GameTile(kind: k, size: 32)
            } else {
                Image("HeaderIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            Text(title.uppercased())
                .font(.system(size: 19, weight: .heavy, design: .serif))
                .tracking(1.5)
                .foregroundColor(GC.onLeather)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 4)
            trailing
                .foregroundColor(GC.onLeather)
        }
        if let below = below {
            below
        }
        }
        .padding(.leading, 12 + edgePad.leading)
        .padding(.trailing, 12 + edgePad.trailing)
        .padding(.top, 8 + edgePad.top)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .background(LeatherBar().ignoresSafeArea(edges: [.top, .horizontal]))
    }
}

extension GCHeader where Trailing == EmptyView {
    init(_ title: String, showBack: Bool = true) {
        self.init(title, showBack: showBack, trailing: { EmptyView() })
    }
}

/// A round header button (no system glass).
struct HeaderButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(GC.onLeather)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
    }
}

struct FlatAction: Identifiable {
    let id = UUID()
    let title: String
    var destructive: Bool = false
    let action: () -> Void
}

/// Flat pop-up list that replaces native menus and confirmation dialogs.
struct FlatMenuOverlay: View {
    let title: String
    let actions: [FlatAction]
    let close: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    close()
                }
            VStack(spacing: 0) {
                if !title.isEmpty {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundColor(GC.dim)
                        .padding(.vertical, 12)
                }
                ForEach(actions) { a in
                    Rectangle().fill(GC.surface0).frame(height: 1)
                    Button {
                        close()
                        a.action()
                    } label: {
                        Text(a.title)
                            .font(.body.bold())
                            .foregroundColor(a.destructive ? GC.red : GC.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                    }
                    .buttonStyle(.plain)
                }
                Rectangle().fill(GC.surface0).frame(height: 1)
                Button {
                    close()
                } label: {
                    Text("Cancel")
                        .foregroundColor(GC.dim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 290)
            .background(RoundedRectangle(cornerRadius: 16).fill(GC.base))
        }
    }
}

/// Flat +/- control with a label.
struct FlatStepper: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1

    private func button(_ symbol: String, _ delta: Int) -> some View {
        Button {
            value = min(max(value + delta, range.lowerBound), range.upperBound)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(GC.text)
                .frame(width: 38, height: 34)
                .background(Capsule().fill(GC.rosewater))
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .foregroundColor(GC.text)
            Spacer()
            button("minus", -step)
            button("plus", step)
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
