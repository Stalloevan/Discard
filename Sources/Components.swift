import SwiftUI

let seatColors: [Color] = [
    Color(red: 0.15, green: 0.45, blue: 0.90),
    Color(red: 0.90, green: 0.25, blue: 0.25),
    Color(red: 0.20, green: 0.70, blue: 0.30),
    Color(red: 0.95, green: 0.60, blue: 0.15),
    Color(red: 0.60, green: 0.35, blue: 0.85),
    Color(red: 0.10, green: 0.65, blue: 0.65),
    Color(red: 0.92, green: 0.40, blue: 0.65),
    Color(red: 0.55, green: 0.40, blue: 0.25)
]

func signed(_ n: Int) -> String {
    return n > 0 ? "+\(n)" : "\(n)"
}

struct WheelColumn: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var width: CGFloat = 72

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(GC.dim)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: width)
            Picker(title, selection: $value) {
                ForEach(Array(range), id: \.self) { n in
                    Text("\(n)").tag(n)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: width, height: 100)
            .clipped()
            .environment(\.colorScheme, .dark)
        }
    }
}

struct WheelRow: View {
    let titles: [String]
    let values: [Binding<Int>]
    let range: ClosedRange<Int>

    var body: some View {
        GeometryReader { geo in
            let n = max(titles.count, 1)
            let w = min(76, geo.size.width / CGFloat(n) - 4)
            HStack(spacing: 4) {
                ForEach(0..<titles.count, id: \.self) { i in
                    WheelColumn(title: titles[i], value: values[i], range: range, width: w)
                }
            }
            .frame(width: geo.size.width)
        }
        .frame(height: 124)
    }
}
