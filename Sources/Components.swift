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

/// One big drum for the player you pick. Players are chips on top; fields are a
/// segmented control; the drum, with -/+ buttons, edits the chosen player and field.
struct DrumPad: View {
    let titles: [String]
    let fieldNames: [String]
    @Binding var values: [[Int]]          // values[field][unit]
    let ranges: (Int, Int) -> ClosedRange<Int>   // (field, unit)
    let summary: (Int) -> String
    var info: ((Int) -> String)? = nil

    @State private var unit = 0
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

    private func chip(_ i: Int, selected: Bool) -> some View {
        VStack(spacing: 0) {
            Text(titles[i])
                .font(.caption2.bold())
                .foregroundColor(GC.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(summary(i))
                .font(.system(size: 17, weight: .heavy, design: .serif))
                .foregroundColor(GC.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(selected ? seatColors[i % 8].opacity(0.35) : GC.surface0.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(seatColors[i % 8], lineWidth: selected ? 2.5 : 1)
        )
        .onTapGesture {
            unit = i
        }
    }

    private func stepButton(_ symbol: String, _ delta: Int, _ f: Int, _ u: Int) -> some View {
        Button {
            write(f, u, current(f, u) + delta)
        } label: {
            Image(systemName: symbol)
                .font(.title2.bold())
                .foregroundColor(GC.text)
                .frame(width: 46, height: 46)
                .background(Circle().fill(GC.button))
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        let n = max(titles.count, 1)
        let f = min(field, max(fieldNames.count - 1, 0))
        let u = min(unit, n - 1)
        VStack(spacing: 8) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: min(n, 4)),
                spacing: 6
            ) {
                ForEach(0..<titles.count, id: \.self) { i in
                    chip(i, selected: i == u)
                }
            }
            if fieldNames.count > 1 {
                Picker("Field", selection: $field) {
                    ForEach(0..<fieldNames.count, id: \.self) { i in
                        Text(fieldNames[i]).tag(i)
                    }
                }
                .pickerStyle(.segmented)
            }
            HStack(spacing: 10) {
                stepButton("minus", -1, f, u)
                StampWheel(
                    title: "",
                    value: Binding<Int>(
                        get: { current(f, u) },
                        set: { write(f, u, $0) }
                    ),
                    range: ranges(f, u),
                    width: nil,
                    height: 128,
                    seat: u
                )
                stepButton("plus", 1, f, u)
            }
            if let info = info {
                Text(info(u))
                    .font(.caption)
                    .foregroundColor(GC.dim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}
