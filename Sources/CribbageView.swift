import SwiftUI

// MARK: Board geometry
// Each player has one track that snakes back and forth in as many columns as gives the biggest holes:
// column 1 runs up, column 2 runs down, column 3 up again, and so on. Only the stretch that can matter is
// shown: from the lowest peg up to the highest peg + 29 (the best possible hand).

struct SnakeGeo {
    let size: CGSize
    let count: Int
    let lo: Int
    let hi: Int
    let top: CGFloat = 4
    let bottom: CGFloat = 4
    let side: CGFloat = 2
    let perRow: Int = 5
    let rowCount: Int

    init(size: CGSize, count: Int, lo: Int, hi: Int) {
        self.size = size
        self.count = count
        self.lo = lo
        self.hi = hi
        self.rowCount = hi / 5 - lo / 5 + 1
    }

    var laneWidth: CGFloat {
        return (size.width - 2 * side) / CGFloat(max(count, 1))
    }

    var cellW: CGFloat {
        return (laneWidth - 6) / CGFloat(perRow)
    }

    var cellH: CGFloat {
        return (size.height - top - bottom) / CGFloat(max(rowCount, 1))
    }

    var cell: CGFloat {
        return min(cellW, cellH)
    }

    /// Pegs are small; the holes they sit in are big.
    var pegSize: CGFloat {
        return min(max(cell * 0.5, 12), 26)
    }

    var holeRadius: CGFloat {
        return min(max(cell * 0.3, 3), 10)
    }

    func laneCenter(_ p: Int) -> CGFloat {
        return side + laneWidth * (CGFloat(p) + 0.5)
    }

    /// The track is an S: the bottom row runs left to right, the next one right to left, and so on up.
    func point(_ p: Int, _ idx: Int) -> CGPoint {
        let i = min(max(idx, lo), hi)
        let absRow = i / 5
        let row = absRow - lo / 5
        let k = i % 5
        let col = absRow % 2 == 0 ? k : 4 - k
        let x = side + laneWidth * CGFloat(p) + 3 + cellW * (CGFloat(col) + 0.5)
        let y = size.height - bottom - cellH * (CGFloat(row) + 0.5)
        return CGPoint(x: x, y: y)
    }

    func hole(_ p: Int, near pt: CGPoint) -> Int {
        var best = lo
        var bestD = CGFloat.greatestFiniteMagnitude
        for idx in lo...hi {
            let q = point(p, idx)
            let dx = q.x - pt.x
            let dy = q.y - pt.y
            let d = dx * dx + dy * dy
            if d < bestD {
                bestD = d
                best = idx
            }
        }
        return best
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
    // Whole rows of five, so the holes never change places - only the spacing between rows does.
    let lo = (max(low - 1, 0) / 5) * 5
    let hi = min((min(high + 29, 121) / 5) * 5 + 4, 121)
    return (lo, max(hi, lo + 9))
}

/// A draggable peg. Big enough for a thumb.
struct PegHandle: View {
    let color: Color
    let diameter: CGFloat
    let position: CGPoint
    let faded: Bool
    let onChange: (CGPoint) -> Void
    let onEnd: (CGPoint) -> Void

    var body: some View {
        Circle()
            .fill(faded ? color.opacity(0.55) : color)
            .overlay(Circle().stroke(GC.base, lineWidth: 3))
            .frame(width: diameter, height: diameter)
            .frame(width: max(diameter + 8, 44), height: max(diameter + 8, 44))
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
    /// (player, whichPeg: 0 = back, 1 = front, hole)
    let onPlace: (Int, Int, Int) -> Void

    @State private var dragPlayer: Int? = nil
    @State private var dragWhich: Int = 0
    @State private var dragHole: Int = 0
    @State private var starts: [Int: Double] = [:]
    @State private var animEnd: Double = 0
    @State private var animating = true

    /// New holes (and the bit of track leading to each) arrive one at a time.
    private func register() {
        let range = visibleRange(pegs)
        let now = Date().timeIntervalSinceReferenceDate
        let base = max(now, animEnd)
        var order = 0
        for idx in range.0...range.1 where starts[idx] == nil {
            starts[idx] = base + Double(order) * 0.05
            order += 1
        }
        if order > 0 {
            let end = base + Double(order) * 0.05 + 0.45
            animEnd = end
            animating = true
            DispatchQueue.main.asyncAfter(deadline: .now() + (end - now) + 0.1) {
                if Date().timeIntervalSinceReferenceDate >= animEnd {
                    animating = false
                }
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            let range = visibleRange(pegs)
            let g = SnakeGeo(size: geo.size, count: pegs.count, lo: range.0, hi: range.1)
            ZStack(alignment: .topLeading) {
                TimelineView(.animation(minimumInterval: nil, paused: !animating)) { tl in
                    let now = animating ? tl.date.timeIntervalSinceReferenceDate : Double.infinity
                    Canvas { ctx, sz in
                        drawBoard(ctx: &ctx, g: g, now: now)
                    }
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
            .onAppear {
                register()
            }
            .onChange(of: range.0 * 1000 + range.1) { _, _ in
                register()
            }
        }
    }

    private func backShown(_ p: Int) -> Int {
        if dragPlayer == p && dragWhich == 0 { return dragHole }
        return pegs[p].back
    }

    private func frontShown(_ p: Int) -> Int {
        if dragPlayer == p && dragWhich == 1 { return dragHole }
        return pegs[p].front
    }

    private func gainBadge(_ p: Int, _ g: SnakeGeo) -> some View {
        let back = backShown(p)
        let front = frontShown(p)
        let delta = abs(front - back)
        let color = seatColors[p % 8]
        let a = g.point(p, back)
        let b = g.point(p, front)
        let apart = hypot(a.x - b.x, a.y - b.y)
        let big = apart >= g.pegSize * 2.2
        let upper = a.y < b.y ? a : b
        let pos = big
            ? CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            : CGPoint(x: upper.x, y: upper.y - g.pegSize * 0.5 - 12)
        return ZStack {
            if delta > 0 {
                Text("+\(delta)")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(GC.base)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(GC.text))
                    .overlay(Capsule().stroke(color, lineWidth: 2))
                    .position(x: pos.x, y: max(pos.y, 10))
            }
        }
        .allowsHitTesting(false)
    }

    private func pegViews(_ p: Int, _ g: SnakeGeo) -> some View {
        let color = seatColors[p % 8]
        let peg = pegs[p]
        let d = g.pegSize
        return ZStack {
            // Front (leading) peg: drag it back to undo a mistaken move
            PegHandle(
                color: color,
                diameter: d,
                position: g.point(p, frontShown(p)),
                faded: true,
                onChange: { pt in
                    if dragPlayer == nil {
                        dragPlayer = p
                        dragWhich = 1
                    }
                    dragHole = g.hole(p, near: pt)
                },
                onEnd: { pt in
                    let h = g.hole(p, near: pt)
                    dragPlayer = nil
                    onPlace(p, 1, h)
                }
            )
            // Back peg: drag it ahead to leapfrog and score
            PegHandle(
                color: color,
                diameter: d * 0.9,
                position: g.point(p, backShown(p)),
                faded: false,
                onChange: { pt in
                    if dragPlayer == nil {
                        dragPlayer = p
                        dragWhich = 0
                    }
                    dragHole = g.hole(p, near: pt)
                },
                onEnd: { pt in
                    let h = g.hole(p, near: pt)
                    dragPlayer = nil
                    onPlace(p, 0, h)
                }
            )
        }
    }

    private func loupe(_ p: Int, _ g: SnakeGeo) -> some View {
        let color = seatColors[p % 8]
        let peg = pegs[p]
        let note: String
        if dragWhich == 0 {
            note = dragHole > peg.front ? "+\(dragHole - peg.front)" : (dragHole == peg.back ? "stay" : "back peg")
        } else {
            note = dragHole < peg.front ? "undo \(peg.front - dragHole)" : (dragHole == peg.front ? "stay" : "+\(dragHole - peg.front)")
        }
        let at = g.point(p, dragHole)
        let x = min(max(at.x, 44), g.size.width - 44)
        let y = max(at.y - g.pegSize - 34, 28)
        return VStack(spacing: 0) {
            Text("\(dragHole)")
                .font(.system(size: 24, weight: .heavy, design: .serif))
                .foregroundColor(GC.base)
            Text(note)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(GC.base.opacity(0.85))
        }
        .frame(width: 80, height: 48)
        .background(RoundedRectangle(cornerRadius: 12).fill(color))
        .position(x: x, y: y)
        .allowsHitTesting(false)
    }

    /// 0 before a piece's moment, 1 once it has settled.
    private func progress(_ idx: Int, _ now: Double) -> Double {
        guard let t0 = starts[idx] else { return 0 }
        if now == Double.infinity { return 1 }
        return min(max((now - t0) / 0.4, 0), 1)
    }

    private func drawBoard(ctx: inout GraphicsContext, g: SnakeGeo, now: Double) {
        let n = pegs.count
        if n == 0 { return }
        let dot = g.holeRadius

        for p in 0..<n {
            let color = seatColors[p % 8]
            let x0 = g.side + g.laneWidth * CGFloat(p) + 2
            let rect = CGRect(x: x0, y: 0, width: g.laneWidth - 4, height: g.size.height)
            ctx.fill(Path(roundedRect: rect, cornerRadius: 10), with: .color(color.opacity(0.16)))
            ctx.stroke(Path(roundedRect: rect, cornerRadius: 10), with: .color(color.opacity(0.6)), lineWidth: 1)

            // The S-shaped track: each piece swings down from a slight angle and levels out
            if g.hi > g.lo {
                for idx in (g.lo + 1)...g.hi {
                    let pr = progress(idx, now)
                    if pr <= 0 { continue }
                    let e = 1 - pow(1 - pr, 3)
                    let a = g.point(p, idx - 1)
                    let b = g.point(p, idx)
                    let theta = (1 - e) * 0.35
                    let dx = b.x - a.x
                    let dy = b.y - a.y
                    let rx = dx * cos(theta) - dy * sin(theta)
                    let ry = dx * sin(theta) + dy * cos(theta)
                    var seg = Path()
                    seg.move(to: a)
                    seg.addLine(to: CGPoint(x: a.x + rx, y: a.y + ry - (1 - e) * 6))
                    ctx.stroke(
                        seg,
                        with: .color(color.opacity(0.35 * min(1, pr * 2))),
                        style: StrokeStyle(lineWidth: max(dot, 2), lineCap: .round)
                    )
                }
            }

            for idx in g.lo...g.hi {
                let pr = progress(idx, now)
                if pr <= 0 { continue }
                let e = 1 - pow(1 - pr, 3)
                let pt = g.point(p, idx)
                let lift = CGFloat(1 - e) * max(g.cellH, 14) * 0.9
                let five = idx % 5 == 0
                let c: Color = five ? GC.dim : GC.surface1
                let center = CGPoint(x: pt.x, y: pt.y - lift)
                let dotRect = CGRect(x: center.x - dot, y: center.y - dot, width: 2 * dot, height: 2 * dot)
                ctx.fill(Path(ellipseIn: dotRect), with: .color(c.opacity(min(1, pr * 2))))
                if five && dot >= 6 {
                    let t = Text("\(idx)")
                        .font(.system(size: min(dot * 1.1, 10), weight: .bold))
                        .foregroundColor(GC.base)
                    ctx.draw(t, at: center)
                }
            }
        }
    }
}

struct CribbageBoardView: View {
    let matchID: UUID
    @EnvironmentObject var store: Store
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
                    onPlace: { p, which, hole in
                        place(p, which, hole)
                    }
                )
                if !m.finished {
                    wheels(m)
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
                StampWheel(title: "", value: amount, range: 1...cap, width: nil, height: 70, seat: i)
                    .padding(.horizontal, 2)
                Button {
                    place(i, 0, front + min(amounts[i], cap))
                    amounts[i] = 1
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(seatColors[i % 8])
                }
                .buttonStyle(.plain)
            } else {
                Text("Home")
                    .font(.caption.bold())
                    .foregroundColor(GC.dim)
                    .frame(height: 70)
            }
        }
    }

    /// which == 0 (back peg): a hole ahead of the front peg leapfrogs it; otherwise it just moves the back peg.
    /// which == 1 (front peg): dragging it back undoes a move (restoring the old back peg when it can);
    /// dragging it forward just corrects the front peg.
    private func place(_ u: Int, _ which: Int, _ hole: Int) {
        store.mutate(matchID) { m in
            if m.finished { return }
            if u >= m.pegs.count { return }
            var p = m.pegs[u]
            if which == 0 {
                if hole > p.front {
                    p.back = p.front
                    p.front = hole
                } else if hole != p.back {
                    p.back = hole
                } else {
                    return
                }
            } else {
                if hole == p.front { return }
                if hole < p.front {
                    var restored = false
                    for old in m.pegHistory.reversed() where u < old.count {
                        if old[u].front == hole {
                            p = old[u]
                            restored = true
                            break
                        }
                    }
                    if !restored {
                        p.front = hole
                        if p.back > hole { p.back = hole }
                    }
                } else {
                    p.front = hole
                }
            }
            m.pegHistory.append(m.pegs)
            if m.pegHistory.count > 60 {
                m.pegHistory.removeFirst()
            }
            m.pegs[u] = p
        }
    }
}
