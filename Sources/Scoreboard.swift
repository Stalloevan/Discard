import SwiftUI

/// One scoreboard used by every game: a row of glossy score bubbles.
struct ScoreStrip: View {
    let m: GameMatch
    @EnvironmentObject var store: Store

    var body: some View {
        let n = max(m.units.count, 1)
        let leaders = m.leaders
        GeometryReader { geo in
            let cell = geo.size.width / CGFloat(n)
            let bubble = min(72, max(38, cell - 8))
            HStack(alignment: .top, spacing: 0) {
                ForEach(0..<m.units.count, id: \.self) { i in
                    cellView(i, bubble: bubble, leaders: leaders)
                        .frame(width: cell)
                }
            }
        }
        .frame(height: 128)
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

    private func cellView(_ i: Int, bubble: CGFloat, leaders: [Int]) -> some View {
        let u = m.units[i]
        let isLeader = leaders.contains(i) && leaders.count < m.units.count
        let hasDealer = u.members.contains(m.dealer)
        let extra = extraLine(i)
        return VStack(spacing: 2) {
            ZStack(alignment: .topTrailing) {
                Bubble(color: seatColors[i % 8], size: bubble) {
                    Text("\(m.total(i))")
                        .font(.system(size: bubble * 0.38, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, 4)
                        .shadow(color: Color.black.opacity(0.5), radius: 1, x: 0, y: 1)
                }
                .overlay(Circle().stroke(isLeader ? GC.gold : Color.clear, lineWidth: 3))
                if hasDealer {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.black)
                        .padding(4)
                        .background(Circle().fill(GC.gold))
                        .offset(x: 4, y: -4)
                }
            }
            Text(u.name)
                .font(.caption.bold())
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if !u.subtitle.isEmpty {
                Text(u.subtitle)
                    .font(.caption2)
                    .foregroundColor(GC.dim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            if !extra.isEmpty {
                Text(extra)
                    .font(.caption2)
                    .foregroundColor(m.kind == .spades ? GC.dim : GC.gold)
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
                .foregroundColor(.white)
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
                    .foregroundColor(.white)
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
        .background(Capsule().fill(Color.black.opacity(0.35)))
        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
    }
}
