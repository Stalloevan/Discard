import SwiftUI

/// Latte accents, one per seat.
let seatHex: [UInt32] = [0x1E66F5, 0xD20F39, 0x40A02B, 0xFE640B, 0x8839EF, 0x179299, 0xEA76CB, 0xDF8E1D]

let seatColors: [Color] = seatHex.map { Color(hex: $0) }

/// The tan of the scoring wheel: one tan per seat, each leaning slightly toward that seat's accent.
func tanColor(_ i: Int) -> Color {
    let hex = seatHex[((i % 8) + 8) % 8]
    let sr = Double((hex >> 16) & 0xFF) / 255.0
    let sg = Double((hex >> 8) & 0xFF) / 255.0
    let sb = Double(hex & 0xFF) / 255.0
    let mix = 0.16
    return Color(
        red: 0.83 * (1 - mix) + sr * mix,
        green: 0.71 * (1 - mix) + sg * mix,
        blue: 0.55 * (1 - mix) + sb * mix
    )
}

func signed(_ n: Int) -> String {
    return n > 0 ? "+\(n)" : "\(n)"
}

/// A binding that never lets a group of values add up to more than `cap`.
func remainingRange(_ values: [Int], _ i: Int, cap: Int) -> ClosedRange<Int> {
    var others = 0
    for (j, v) in values.enumerated() where j != i {
        others += v
    }
    return 0...max(0, cap - others)
}

/// Where everyone sits. Even counts split evenly across the two long sides of the table;
/// an odd count adds the last person at the end of the table.
struct TableSeating {
    let bottom: [Int]
    let top: [Int]
    let end: Int?
}

func tableSeating(_ n: Int) -> TableSeating {
    if n <= 1 { return TableSeating(bottom: Array(0..<max(n, 0)), top: [], end: nil) }
    let k = n / 2
    return TableSeating(
        bottom: Array(0..<k),
        top: Array(k..<(2 * k)),      // the row is turned 180 degrees, so these run right to left on screen
        end: n % 2 == 1 ? n - 1 : nil
    )
}

/// Turns its content a quarter turn so it faces the person at the end of the table.
struct EndFacing<Content: View>: View {
    let content: Content

    init(@ViewBuilder _ content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { geo in
            content
                .frame(width: geo.size.height, height: geo.size.width)
                .rotationEffect(.degrees(-90))
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

/// The table: the far side's cells are turned upside down, the end seat is turned a quarter turn,
/// and the middle strip stays upright for whoever is running the game.
struct TableView<Cell: View, Center: View>: View {
    let count: Int
    var centerHeight: CGFloat
    var endWidth: CGFloat
    let cell: (Int) -> Cell
    let center: Center

    init(count: Int, centerHeight: CGFloat = 44, endWidth: CGFloat = 96, @ViewBuilder cell: @escaping (Int) -> Cell, @ViewBuilder center: () -> Center) {
        self.count = count
        self.centerHeight = centerHeight
        self.endWidth = endWidth
        self.cell = cell
        self.center = center()
    }

    private func row(_ ids: [Int], _ h: CGFloat) -> some View {
        HStack(spacing: 6) {
            ForEach(ids, id: \.self) { i in
                cell(i)
                    .frame(maxWidth: .infinity)
                    .frame(height: h)
            }
        }
        .frame(height: h)
    }

    var body: some View {
        let seats = tableSeating(count)
        GeometryReader { geo in
            let hasEnd = seats.end != nil
            let mainW = geo.size.width - (hasEnd ? endWidth + 8 : 0)
            let gaps: CGFloat = centerHeight > 0 ? 12 : 6
            let rowH = max((geo.size.height - centerHeight - gaps) / 2, 40)
            HStack(spacing: 8) {
                VStack(spacing: 6) {
                    row(seats.top, rowH)
                        .rotationEffect(.degrees(180))
                    if centerHeight > 0 {
                        center
                            .frame(height: centerHeight)
                    }
                    row(seats.bottom, rowH)
                }
                .frame(width: mainW)
                if let e = seats.end {
                    EndFacing {
                        cell(e)
                    }
                    .frame(width: endWidth, height: geo.size.height)
                }
            }
        }
    }
}

/// One simple wheel per player, each turned to face that player. Fields are chips in the middle strip;
/// every wheel edits the chosen field for its own player.
struct DrumPad: View {
    let titles: [String]
    let fieldNames: [String]
    @Binding var values: [[Int]]          // values[field][unit]
    let ranges: (Int, Int) -> ClosedRange<Int>   // (field, unit)
    let summary: (Int) -> String
    var info: ((Int) -> String)? = nil
    var onReset: (() -> Void)? = nil
    var status: String = ""
    var statusColor: Color = GC.dim
    var actionTitle: String? = nil
    var actionEnabled: Bool = true
    var action: (() -> Void)? = nil

    @State private var field = 0

    private func current(_ f: Int, _ u: Int) -> Int {
        if f < values.count && u < values[f].count { return values[f][u] }
        return 0
    }

    private func write(_ f: Int, _ u: Int, _ v: Int) {
        let r = ranges(f, u)
        var copy = values
        if f < copy.count && u < copy[f].count {
            copy[f][u] = min(max(v, r.lowerBound), r.upperBound)
            values = copy
        }
    }

    private func resetAll() {
        if let onReset = onReset {
            onReset()
            return
        }
        var copy = values
        for f in 0..<copy.count {
            for u in 0..<copy[f].count {
                copy[f][u] = min(max(0, ranges(f, u).lowerBound), ranges(f, u).upperBound)
            }
        }
        values = copy
    }

    private func wheelCell(_ i: Int, _ f: Int) -> some View {
        GeometryReader { box in
            let wheelH = min(max(box.size.height - 40, 40), 96)
            let wheelW = min(max(box.size.width - 12, 40), 130)
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(seatColors[i % 8])
                        .frame(width: 8, height: 8)
                    Text(titles[i])
                        .font(.caption2.bold())
                        .foregroundColor(GC.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                StampWheel(
                    title: "",
                    value: Binding<Int>(
                        get: { current(f, i) },
                        set: { write(f, i, $0) }
                    ),
                    range: ranges(f, i),
                    width: wheelW,
                    height: wheelH,
                    seat: i
                )
                if fieldNames.count > 1 {
                    Text(summary(i))
                        .font(.caption2)
                        .foregroundColor(GC.dim)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .frame(width: box.size.width, height: box.size.height)
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(GC.mantle))
    }

    private func centerStrip(_ f: Int) -> some View {
        HStack(spacing: 8) {
            if fieldNames.count > 1 {
                ChoiceChips(items: fieldNames, selection: $field, columns: fieldNames.count)
                    .frame(maxWidth: 320)
            }
            if !status.isEmpty {
                Text(status)
                    .font(.subheadline.bold())
                    .foregroundColor(statusColor)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            if let info = info {
                Text(info(0))
                    .font(.caption)
                    .foregroundColor(GC.dim)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            Button {
                resetAll()
            } label: {
                Label("Reset wheels", systemImage: "arrow.counterclockwise")
                    .font(.subheadline.bold())
                    .foregroundColor(GC.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(GC.surface1))
            }
            .buttonStyle(.plain)
            if let t = actionTitle {
                Button(t) {
                    action?()
                }
                .buttonStyle(GlossButtonStyle(compact: true))
                .disabled(!actionEnabled)
            }
        }
        .padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(GC.mantle))
    }

    var body: some View {
        let f = min(field, max(fieldNames.count - 1, 0))
        TableView(
            count: titles.count,
            centerHeight: 46,
            endWidth: 104,
            cell: { i in wheelCell(i, f) },
            center: { centerStrip(f) }
        )
    }
}
