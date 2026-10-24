import SwiftUI

// MARK: Board geometry
// Every player has ONE vertical lane. Only the stretch that can matter is shown: from the lowest
// peg up to the highest peg + 29 (the best possible hand), scaled to fill the board.

struct BoardGeo {
    let size: CGSize
    let count: Int
    let lo: Int
    let hi: Int
    let top: CGFloat = 30
    let bottom: CGFloat = 20
    let side: CGFloat = 4

    var laneWidth: CGFloat {
        return (size.width - 2 * side) / CGFloat(max(count, 1))
    }

    var rowGap: CGFloat {
        return (size.height - top - bottom) / CGFloat(max(hi - lo, 1))
    }

    func laneCenter(_ p: Int) -> CGFloat {
        return side + laneWidth * (CGFloat(p) + 0.5)
    }

    func holeY(_ idx: Int) -> CGFloat {
        return size.height - bottom - CGFloat(idx - lo) * rowGap
    }

    func point(_ p: Int, _ idx: Int) -> CGPoint {
        return CGPoint(x: laneCenter(p), y: holeY(idx))
    }

    func hole(forY y: CGFloat) -> Int {
        let raw = ((size.height - bottom - y) / max(rowGap, 0.1)).rounded()
        return min(max(lo + Int(raw), lo), hi)
    }
}

/// The visible stretch of the board for a set of pegs.
func visibleRange(_ pegs: [Peg]) -> (Int, Int) {
    var low = 121
    var high = 0
    for p in pegs {
        low = min(low, min(p.back, p.front))
        high = max(high, max(p.back, p.front))
    }
    if pegs.isEmpty { return (0, 29) }
    let lo = max(low - 1, 0)
    let hi = min(high + 29, 121)
    return (lo, max(hi, lo + 10))
}

/// The draggable front peg of one player. Big enough for a thumb, and it shows its score.
struct PegHandle: View {
    let color: Color
    let label: String
    let position: CGPoint
    let selected: Bool
    let onChange: (CGPoint) -> Void
    let onEnd: (CGPoint) -> Void

    var body: some View {
        Circle()
            .fill(color)
            .overlay(Circle().stroke(GC.base, lineWidth: 3))
            .overlay(
                Text(label)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(GC.base)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            )
            .frame(width: 34, height: 34)
            .frame(width: 46, height: 46)
            .contentShape(Circle())
            .position(position)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("board"))
                    .onChanged { g in
                        onChange(g.location)
                    }
                    .onEnded { g in
                        onEnd(g.location)
                    }
            )
    }
}

struct PegBoard: View {
    let names: [String]
    let pegs: [Peg]
    let selected: Int
    let previews: [Int]         // holes each player's wheel would add
    let onSelect: (Int) -> Void
    let onPlace: (Int, Int) -> Void

    @State private var dragPlayer: Int? = nil
    @State private var dragHole: Int = 0

    var body: some View {
        GeometryReader { geo in
            let range = visibleRange(pegs)
            let g = BoardGeo(size: geo.size, count: pegs.count, lo: range.0, hi: range.1)
            ZStack(alignment: .topLeading) {
                Canvas { ctx, sz in
                    drawBoard(ctx: &ctx, g: g)
                }
                .frame(width: geo.size.width, height: geo.size.height)

                ForEach(0..<pegs.count, id: \.self) { p in
                    pegViews(p, g)
                }

                ForEach(0..<pegs.count, id: \.self) { p in
                    gainBadge(p, g)
                }

                if let p = dragPlayer, p < pegs.count {
                    loupe(p, g)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .coordinateSpace(name: "board")
        }
    }

    private func frontHole(_ p: Int) -> Int {
        if dragPlayer == p { return dragHole }
        return pegs[p].front
    }

    private func gainBadge(_ p: Int, _ g: BoardGeo) -> some View {
        let back = pegs[p].back
        let front = frontHole(p)
        let delta = front - back
        let color = seatColors[p % 8]
        let a = g.point(p, back)
        let b = g.point(p, front)
        let apart = abs(a.y - b.y)
        let y = apart >= 44 ? (a.y + b.y) / 2 : b.y - 30
        return ZStack {
            if delta > 0 {
                Text("+\(delta)")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(GC.base)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(GC.text))
                    .overlay(Capsule().stroke(color, lineWidth: 2))
                    .position(x: g.laneCenter(p), y: max(y, 12))
            }
        }
        .allowsHitTesting(false)
    }

    private func pegViews(_ p: Int, _ g: BoardGeo) -> some View {
        let color = seatColors[p % 8]
        let peg = pegs[p]
        let backPt = g.point(p, peg.back)
        let frontPt = g.point(p, frontHole(p))
        let add = p < previews.count ? previews[p] : 0
        return ZStack {
            if peg.back != peg.front || dragPlayer == p {
                Path { path in
                    path.move(to: backPt)
                    path.addLine(to: frontPt)
                }
                .stroke(color.opacity(0.45), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .allowsHitTesting(false)
                Circle()
                    .fill(color.opacity(0.65))
                    .overlay(Circle().stroke(GC.base, lineWidth: 2))
                    .frame(width: 24, height: 24)
                    .position(backPt)
                    .allowsHitTesting(false)
            }
            if add > 0 && dragPlayer == nil && peg.front + add <= g.hi {
                Circle()
                    .strokeBorder(color, style: StrokeStyle(lineWidth: 3, dash: [4, 3]))
                    .frame(width: 34, height: 34)
                    .position(g.point(p, peg.front + add))
                    .allowsHitTesting(false)
            }
            PegHandle(
                color: color,
                label: "\(frontHole(p))",
                position: frontPt,
                selected: selected == p,
                onChange: { pt in
                    if dragPlayer == nil {
                        dragPlayer = p
                        onSelect(p)
                    }
                    dragHole = g.hole(forY: pt.y)
                },
                onEnd: { pt in
                    let h = g.hole(forY: pt.y)
                    dragPlayer = nil
                    onPlace(p, h)
                }
            )
        }
    }

    private func loupe(_ p: Int, _ g: BoardGeo) -> some View {
        let color = seatColors[p % 8]
        let gain = max(dragHole - pegs[p].front, 0)
        let note = gain > 0 ? "+\(gain)" : (dragHole == pegs[p].front ? "stay" : "back")
        let x = min(max(g.laneCenter(p), 44), g.size.width - 44)
        let y = max(g.holeY(dragHole) - 64, 28)
        return VStack(spacing: 0) {
            Text("\(dragHole)")
                .font(.system(size: 24, weight: .heavy, design: .serif))
                .foregroundColor(GC.base)
            Text(note)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(GC.base.opacity(0.85))
        }
        .frame(width: 76, height: 48)
        .background(RoundedRectangle(cornerRadius: 12).fill(color))
        .position(x: x, y: y)
        .allowsHitTesting(false)
    }

    private func drawBoard(ctx: inout GraphicsContext, g: BoardGeo) {
        let n = pegs.count
        if n == 0 { return }
        let dot = min(g.rowGap * 0.3, 3.0)

        for p in 0..<n {
            let color = seatColors[p % 8]
            let x0 = g.side + g.laneWidth * CGFloat(p) + 2
            let rect = CGRect(x: x0, y: g.holeY(g.hi) - 12, width: g.laneWidth - 4, height: g.holeY(g.lo) - g.holeY(g.hi) + 24)
            let isSel = selected == p
            ctx.fill(Path(roundedRect: rect, cornerRadius: 10), with: .color(color.opacity(isSel ? 0.28 : 0.16)))
            ctx.stroke(Path(roundedRect: rect, cornerRadius: 10), with: .color(color.opacity(isSel ? 1.0 : 0.55)), lineWidth: isSel ? 2.5 : 1)

            let label = Text(String(names[p].prefix(4)))
                .font(.system(size: 12, weight: .heavy, design: .serif))
                .foregroundColor(GC.text)
            ctx.draw(label, at: CGPoint(x: g.laneCenter(p), y: max(g.holeY(g.hi) - 22, 10)))

            for idx in g.lo...g.hi {
                let pt = g.point(p, idx)
                let special = idx == 61 || idx == 91 || idx == 121
                let five = idx % 5 == 0
                let r: CGFloat = special ? dot * 1.5 : (five ? dot * 1.25 : dot)
                let dotRect = CGRect(x: pt.x - r, y: pt.y - r, width: 2 * r, height: 2 * r)
                var c: Color = five ? GC.dim : GC.overlay
                if special { c = GC.red }
                ctx.fill(Path(ellipseIn: dotRect), with: .color(c))
                if five && p == 0 {
                    let t = Text("\(idx)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(GC.dim)
                    ctx.draw(t, at: CGPoint(x: 8, y: pt.y))
                }
            }
        }
    }
}

struct CribbageBoardView: View {
    let matchID: UUID
    @EnvironmentObject var store: Store
    @State private var selected = 0
    @State private var amounts: [Int] = Array(repeating: 1, count: 8)

    private var match: GameMatch? {
        return store.matches.first { $0.id == matchID }
    }

    var body: some View {
        if let m = match {
            VStack(spacing: 6) {
                PegBoard(
                    names: m.names,
                    pegs: m.pegs,
                    selected: min(selected, max(m.names.count - 1, 0)),
                    previews: m.finished ? [] : Array(amounts.prefix(m.names.count)),
                    onSelect: { p in selected = p },
                    onPlace: { p, hole in
                        selected = p
                        place(p, hole)
                    }
                )
                if !m.finished {
                    wheels(m)
                }
                HStack {
                    Spacer()
                    Button {
                        undo()
                    } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                            .font(.subheadline)
                    }
                    .foregroundColor(GC.text)
                    .disabled(m.pegHistory.isEmpty)
                    Menu {
                        Button(role: .destructive) {
                            resetBoard()
                        } label: {
                            Label("Reset the board", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundColor(GC.text)
                    }
                }
            }
        }
    }

    /// One tan wheel per player, lined up under that player's lane.
    private func wheels(_ m: GameMatch) -> some View {
        return HStack(alignment: .top, spacing: 0) {
            ForEach(0..<m.names.count, id: \.self) { i in
                wheelCell(m, i)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 4)
    }

    private func wheelCell(_ m: GameMatch, _ i: Int) -> some View {
        let front = i < m.pegs.count ? m.pegs[i].front : 0
        let cap = min(29, max(121 - front, 0))
        let amount = Binding<Int>(
            get: { min(max(amounts[i], 1), max(cap, 1)) },
            set: { amounts[i] = $0 }
        )
        return VStack(spacing: 3) {
            if cap >= 1 {
                StampWheel(title: "", value: amount, range: 1...cap, width: nil, height: 78, seat: i)
                    .padding(.horizontal, 2)
                Button {
                    selected = i
                    place(i, front + min(amounts[i], cap))
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(seatColors[i % 8])
                }
                .buttonStyle(.plain)
            } else {
                Text("Home")
                    .font(.caption.bold())
                    .foregroundColor(GC.dim)
                    .frame(height: 78)
            }
        }
    }

    private func place(_ u: Int, _ hole: Int) {
        store.mutate(matchID) { m in
            if m.finished { return }
            if u >= m.pegs.count { return }
            var p = m.pegs[u]
            if hole == p.front { return }
            m.pegHistory.append(m.pegs)
            if m.pegHistory.count > 60 {
                m.pegHistory.removeFirst()
            }
            if hole > p.front {
                p.back = p.front
                p.front = hole
            } else {
                p.front = hole
                if p.back > hole { p.back = hole }
            }
            m.pegs[u] = p
        }
    }

    private func undo() {
        store.mutate(matchID) { m in
            if let last = m.pegHistory.last {
                m.pegs = last
                m.pegHistory.removeLast()
            }
        }
    }

    private func resetBoard() {
        store.mutate(matchID) { m in
            m.pegs = Array(repeating: Peg(), count: m.names.count)
            m.pegHistory = []
        }
    }
}
