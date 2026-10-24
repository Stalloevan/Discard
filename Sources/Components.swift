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

/// One simple tan wheel per player, all on screen together. Fields are a segmented control;
/// every wheel edits the chosen field for its own player.
struct DrumPad: View {
    let titles: [String]
    let fieldNames: [String]
    @Binding var values: [[Int]]          // values[field][unit]
    let ranges: (Int, Int) -> ClosedRange<Int>   // (field, unit)
    let summary: (Int) -> String
    var info: ((Int) -> String)? = nil

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

    private func cell(_ i: Int, _ f: Int, wheelHeight: CGFloat) -> some View {
        VStack(spacing: 3) {
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
                width: nil,
                height: wheelHeight,
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
    }

    var body: some View {
        let n = max(titles.count, 1)
        let f = min(field, max(fieldNames.count - 1, 0))
        let perRow = n <= 4 ? n : (n + 1) / 2
        let rows: [[Int]] = stride(from: 0, to: titles.count, by: perRow).map { start in
            Array(start..<min(start + perRow, titles.count))
        }
        VStack(spacing: 8) {
            if fieldNames.count > 1 {
                Picker("Field", selection: $field) {
                    ForEach(0..<fieldNames.count, id: \.self) { i in
                        Text(fieldNames[i]).tag(i)
                    }
                }
                .pickerStyle(.segmented)
            }
            ForEach(0..<rows.count, id: \.self) { r in
                HStack(alignment: .top, spacing: 6) {
                    ForEach(rows[r], id: \.self) { i in
                        cell(i, f, wheelHeight: 92)
                            .frame(maxWidth: .infinity)
                    }
                    if rows[r].count < perRow {
                        ForEach(0..<(perRow - rows[r].count), id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                        }
                    }
                }
            }
            if let info = info {
                Text(info(0))
                    .font(.caption)
                    .foregroundColor(GC.dim)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}
