import SwiftUI

/// One scoreboard used by every game: a stitched leather plate with a score tile per player or team.
struct ScoreStrip: View {
    let m: GameMatch
    @EnvironmentObject var store: Store

    var body: some View {
        let n = max(m.units.count, 1)
        let leaders = m.leaders
        GeometryReader { geo in
            let cell = (geo.size.width - 24) / CGFloat(n)
            HStack(alignment: .top, spacing: 0) {
                ForEach(0..<m.units.count, id: \.self) { i in
                    cellView(i, cell: cell, leaders: leaders)
                        .frame(width: cell)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
        }
        .frame(height: 124)
        .background(LeatherBackground(corner: 18))
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
        let hasDealer = u.members.contains(m.dealer)
        let extra = extraLine(i)
        let tileW = max(cell - 8, 30)
        let color = seatColors[i % 8]
        return VStack(spacing: 2) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(GC.base)
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.22))
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isLeader ? GC.yellow : color, lineWidth: isLeader ? 3.5 : 1.5)
                    Text("\(m.total(i))")
                        .font(.system(size: min(30, tileW * 0.46), weight: .heavy, design: .serif))
                        .foregroundColor(GC.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, 3)
                }
                .frame(width: tileW, height: 56)
                if hasDealer {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: 9))
                        .foregroundColor(GC.text)
                        .padding(4)
                        .background(Circle().fill(GC.yellow))
                        .offset(x: 3, y: -5)
                }
            }
            Text(u.name)
                .font(.caption.bold())
                .foregroundColor(GC.onLeather)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if !u.subtitle.isEmpty {
                Text(u.subtitle)
                    .font(.caption2)
                    .foregroundColor(GC.onLeatherDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            if !extra.isEmpty {
                Text(extra)
                    .font(.caption2)
                    .foregroundColor(GC.onLeather)
                    .lineLimit(1)
            }
        }
    }
}

struct DealerBar: View {
    let m: GameMatch
    let matchID: UUID
    @EnvironmentObject var store: Store

    var body: some View {
        let name = m.dealer < m.names.count ? m.names[m.dealer] : ""
        HStack(spacing: 8) {
            Image(systemName: "rectangle.stack.fill")
                .foregroundColor(GC.gold)
            Text("Dealer")
                .foregroundColor(GC.dim)
            Text(name)
                .bold()
                .foregroundColor(GC.text)
                .lineLimit(1)
            if m.kind == .cribbage {
                Text("· crib \(GameRules.cribSize(m.names.count)) cards")
                    .font(.caption)
                    .foregroundColor(GC.dim)
            }
            Spacer()
            Menu {
                ForEach(0..<m.names.count, id: \.self) { i in
                    Button(m.names[i]) {
                        store.mutate(matchID) { mm in
                            mm.dealer = i
                        }
                    }
                }
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.title3)
                    .foregroundColor(GC.text)
            }
            Button("Next") {
                store.mutate(matchID) { mm in
                    mm.dealer = (mm.dealer + 1) % mm.names.count
                }
            }
            .buttonStyle(GlossButtonStyle(compact: true))
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(GC.mantle))
    }
}
