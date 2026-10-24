import SwiftUI

/// The scores, built into the leather header: one tile per player or team.
struct ScoreStrip: View {
    let m: GameMatch
    @EnvironmentObject var store: Store

    var body: some View {
        let n = max(m.units.count, 1)
        let leaders = m.leaders
        GeometryReader { geo in
            let cell = geo.size.width / CGFloat(n)
            HStack(alignment: .top, spacing: 0) {
                ForEach(0..<m.units.count, id: \.self) { i in
                    cellView(i, cell: cell, leaders: leaders)
                        .frame(width: cell)
                }
            }
        }
        .frame(height: 70)
    }

    private func extraLine(_ i: Int) -> String {
        let u = m.units[i]
        if m.kind == .spades {
            return "bags \(m.bags(i))/10"
        }
        if u.members.count == 1 && u.members[0] < m.names.count {
            let w = store.wins(m.names[u.members[0]], m.kind)
            if w > 0 { return "★ \(w)" }
        }
        return ""
    }

    private func cellView(_ i: Int, cell: CGFloat, leaders: [Int]) -> some View {
        let u = m.units[i]
        let isLeader = leaders.contains(i) && leaders.count < m.units.count
        let extra = extraLine(i)
        let tileW = max(cell - 6, 28)
        let color = seatColors[i % 8]
        return VStack(spacing: 2) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(GC.base)
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.22))
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isLeader ? GC.yellow : color, lineWidth: isLeader ? 3.5 : 1.5)
                Text("\(m.total(i))")
                    .font(.system(size: min(26, tileW * 0.44), weight: .heavy, design: .serif))
                    .foregroundColor(GC.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 3)
            }
            .frame(width: tileW, height: 40)
            Text(extra.isEmpty ? u.name : "\(u.name) · \(extra)")
                .font(.caption.bold())
                .foregroundColor(GC.onLeather)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            if !u.subtitle.isEmpty {
                Text(u.subtitle)
                    .font(.caption2)
                    .foregroundColor(GC.onLeatherDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
    }
}
