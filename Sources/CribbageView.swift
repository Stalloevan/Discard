import SwiftUI

// MARK: Board geometry
// Every player has their own board, turned to face them. The track is an S: the row nearest the player
// runs left to right, the next one right to left, and so on away from them. Holes never change places;
// only the spacing between rows changes as the visible stretch (lowest peg up to highest peg + 29) changes.

struct SnakeGeo {
    let size: CGSize
    let lo: Int
    let hi: Int
    let perRow: Int
    let pad: CGFloat = 4

    /// Holes per row, fixed for a given board size (about 60 holes is the usual stretch).
    static func perRow(for size: CGSize) -> Int {
        var best = 5
        var bestScore: CGFloat = 0
        for k in [5, 10, 15, 20, 25, 30] {
            let rows = Int((60.0 / Double(k)).rounded(.up))
            let cell = min((size.width - 8) / CGFloat(k), (size.height - 8) / CGFloat(rows))
            if cell > bestScore + 0.5 {
                bestScore = cell
                best = k
            }
        }
        return best
    }

    var rowCount: Int {
        return hi / perRow - lo / perRow + 1
    }

    var cellW: CGFloat {
        return (size.width - 2 * pad) / CGFloat(perRow)
    }

    var cellH: CGFloat {
        return (size.height - 2 * pad) / CGFloat(max(rowCount, 1))
    }

    var cell: CGFloat {
        return min(cellW, cellH)
    }

    /// Pegs are small; the holes they sit in are big.
    var pegSize: CGFloat {
        return min(max(cell * 0.5, 10), 24)
    }

    var holeRadius: CGFloat {
        return min(max(cell * 0.3, 3), 10)
    }

    func point(_ idx: Int) -> CGPoint {
        let i = min(max(idx, lo), hi)
        let absRow = i / perRow
        let row = absRow - lo / perRow
        let k = i % perRow
        let col = absRow % 2 == 0 ? k : perRow - 1 - k
        let x = pad + cellW * (CGFloat(col) + 0.5)
        let y = size.height - pad - cellH * (CGFloat(row) + 0.5)
        return CGPoint(x: x, y: y)
    }

    func hole(near pt: CGPoint) -> Int {
        var best = lo
        var bestD = CGFloat.greatestFiniteMagnitude
        for idx in lo...hi {
            let q = point(idx)
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

/// The visible stretch of the board: whole rows, from the lowest peg up to the highest peg + 29.
func visibleRange(_ pegs: [Peg], perRow: Int) -> (Int, Int) {
    var low = 121
    var high = 0
    for p in pegs {
        low = min(low, min(p.back, p.front))
        high = max(high, max(p.back, p.front))
    }
    if pegs.isEmpty { return (0, perRow * 2 - 1) }
    let lo = (max(low - 1, 0) / perRow) * perRow
    let top = min(high + 29, 121)
    let hi = min((top / perRow) * perRow + perRow - 1, 121)
    return (lo, max(hi, lo + perRow - 1))
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
            .overlay(Circle().stroke(GC.base, lineWidth: 2.5))
            .frame(width: diameter, height: diameter)
            .frame(width: max(diameter + 8, 40), height: max(diameter + 8, 40))
            .contentShape(Circle())
            .position(position)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("lane"))
                    .onChanged { g in
                        onChange(g.location)
                    }
                    .onEnded { g in
                        onEnd(g.location)
                    }
            )
    }
}

/// One player's board.
struct PegLane: View {
    let player: Int
    let pegs: [Peg]
    let cleared: Bool
    /// (player, whichPeg: 0 = back, 1 = front, hole)
    let onPlace: (Int, Int, Int) -> Void

    @State private var dragging = false
    @State private var dragWhich: Int = 0
    @State private var dragHole: Int = 0
    @State private var starts: [Int: Double] = [:]
    @State private var animEnd: Double = 0
    @State private var animating = true

    private var color: Color {
        return seatColors[player % 8]
    }

    private var mine: Peg {
        return player < pegs.count ? pegs[player] : Peg()
    }

    /// New holes (and the bit of track leading to each) arrive one at a time.
    private func register(_ perRow: Int) {
        let range = visibleRange(pegs, perRow: perRow)
        let now = Date().timeIntervalSinceReferenceDate
        if cleared {
            starts = [:]
            animEnd = 0
        } else {
            starts = starts.filter { $0.key >= range.0 && $0.key <= range.1 }
        }
        let base = max(now, animEnd)
        var order = 0
        for idx in range.0...range.1 where starts[idx] == nil {
            starts[idx] = base + Double(order) * 0.04
            order += 1
        }
        if order > 0 {
            let end = base + Double(order) * 0.04 + 0.45
            animEnd = end
            animating = true
            DispatchQueue.main.asyncAfter(deadline: .now() + (end - now) + 0.1) {
                if Date().timeIntervalSinceReferenceDate >= animEnd {
                    animating = false
                }
            }
        }
    }

    private func backShown() -> Int {
        if dragging && dragWhich == 0 { return dragHole }
        return mine.back
    }

    private func frontShown() -> Int {
        if dragging && dragWhich == 1 { return dragHole }
        return mine.front
    }

    var body: some View {
        GeometryReader { geo in
            let perRow = SnakeGeo.perRow(for: geo.size)
            let range = visibleRange(pegs, perRow: perRow)
            let g = SnakeGeo(size: geo.size, lo: range.0, hi: range.1, perRow: perRow)
            ZStack(alignment: .topLeading) {
                TimelineView(.animation(minimumInterval: nil, paused: !animating)) { tl in
                    let now = animating ? tl.date.timeIntervalSinceReferenceDate : Double.infinity
                    Canvas { ctx, sz in
                        drawBoard(ctx: &ctx, g: g, now: now)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)

                pegViews(g)
                gainBadge(g)
                if dragging {
                    loupe(g)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .coordinateSpace(name: "lane")
            .onAppear {
                register(perRow)
            }
            .onChange(of: range.0 * 1000 + range.1 + (cleared ? 100000 : 0)) { _, _ in
                register(perRow)
            }
        }
    }

    private func gainBadge(_ g: SnakeGeo) -> some View {
        let back = backShown()
        let front = frontShown()
        let delta = abs(front - back)
        let a = g.point(back)
        let b = g.point(front)
        let apart = hypot(a.x - b.x, a.y - b.y)
        let big = apart >= g.pegSize * 2.4
        let upper = a.y < b.y ? a : b
        let pos = big
            ? CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            : CGPoint(x: upper.x, y: upper.y - g.pegSize * 0.5 - 11)
        return ZStack {
            if delta > 0 {
                Text("+\(delta)")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(GC.base)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(GC.text))
                    .overlay(Capsule().stroke(color, lineWidth: 2))
                    .position(x: min(max(pos.x, 20), g.size.width - 20), y: max(pos.y, 10))
            }
        }
        .allowsHitTesting(false)
    }

    private func pegViews(_ g: SnakeGeo) -> some View {
        let d = g.pegSize
        return ZStack {
            // Front (leading) peg: drag it back to undo a mistaken move
            PegHandle(
                color: color,
                diameter: d,
                position: g.point(frontShown()),
                faded: true,
                onChange: { pt in
                    if !dragging {
                        dragging = true
                        dragWhich = 1
                    }
                    dragHole = g.hole(near: pt)
                },
                onEnd: { pt in
                    let h = g.hole(near: pt)
                    dragging = false
                    onPlace(player, 1, h)
                }
            )
            // Back peg: drag it ahead to leapfrog and score
            PegHandle(
                color: color,
                diameter: d * 0.9,
                position: g.point(backShown()),
                faded: false,
                onChange: { pt in
                    if !dragging {
                        dragging = true
                        dragWhich = 0
                    }
                    dragHole = g.hole(near: pt)
                },
                onEnd: { pt in
                    let h = g.hole(near: pt)
                    dragging = false
                    onPlace(player, 0, h)
                }
            )
        }
    }

    private func loupe(_ g: SnakeGeo) -> some View {
        let peg = mine
        let note: String
        if dragWhich == 0 {
            note = dragHole > peg.front ? "+\(dragHole - peg.front)" : (dragHole == peg.back ? "stay" : "back peg")
        } else {
            note = dragHole < peg.front ? "undo \(peg.front - dragHole)" : (dragHole == peg.front ? "stay" : "+\(dragHole - peg.front)")
        }
        let at = g.point(dragHole)
        let x = min(max(at.x, 40), max(g.size.width - 40, 40))
        let y = max(at.y - g.pegSize - 30, 26)
        return VStack(spacing: 0) {
            Text("\(dragHole)")
                .font(.system(size: 20, weight: .heavy, design: .serif))
                .foregroundColor(GC.base)
            Text(note)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(GC.base.opacity(0.85))
        }
        .frame(width: 72, height: 40)
        .background(RoundedRectangle(cornerRadius: 10).fill(color))
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
        let dot = g.holeRadius
        let rect = CGRect(origin: .zero, size: g.size)
        ctx.fill(Path(roundedRect: rect, cornerRadius: 10), with: .color(color.opacity(0.16)))
        ctx.stroke(Path(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 10), with: .color(color.opacity(0.6)), lineWidth: 1)

        // The S-shaped track: each piece swings down from a slight angle and levels out
        if g.hi > g.lo {
            for idx in (g.lo + 1)...g.hi {
                let pr = progress(idx, now)
                if pr <= 0 { continue }
                let e = 1 - pow(1 - pr, 3)
                let a = g.point(idx - 1)
                let b = g.point(idx)
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
            let pt = g.point(idx)
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

struct CribbageBoardView: View {
    let matchID: UUID
    @EnvironmentObject var store: Store
    @State private var amounts: [Int] = Array(repeating: 1, count: 8)

    private var match: GameMatch? {
        return store.matches.first { $0.id == matchID }
    }

    var body: some View {
        if let m = match {
            let cleared = m.pegs.allSatisfy { $0.front == 0 && $0.back == 0 }
            TableView(
                count: m.names.count,
                centerHeight: 0,
                endHeight: 110,
                cell: { i in seat(m, i, cleared: cleared) },
                center: { EmptyView() }
            )
        }
    }

    /// One player's board with their own wheel, upright from where they sit.
    /// Wide cells put the wheel beside the board; narrow ones put it below (nearest the player).
    private func seat(_ m: GameMatch, _ i: Int, cleared: Bool) -> some View {
        GeometryReader { box in
            let wide = box.size.width > box.size.height * 1.15
            Group {
                if wide {
                    HStack(spacing: 6) {
                        lane(m, i, cleared)
                        if !m.finished {
                            wheelColumn(m, i, vertical: true)
                                .frame(width: 62)
                        }
                    }
                } else {
                    VStack(spacing: 6) {
                        lane(m, i, cleared)
                        if !m.finished {
                            wheelColumn(m, i, vertical: false)
                                .frame(height: 74)
                        }
                    }
                }
            }
            .padding(5)
            .frame(width: box.size.width, height: box.size.height)
            .background(RoundedRectangle(cornerRadius: 12).fill(GC.mantle))
        }
    }

    private func lane(_ m: GameMatch, _ i: Int, _ cleared: Bool) -> some View {
        PegLane(player: i, pegs: m.pegs, cleared: cleared) { p, which, hole in
            place(p, which, hole)
        }
    }

    private func wheelColumn(_ m: GameMatch, _ i: Int, vertical: Bool) -> some View {
        let front = i < m.pegs.count ? m.pegs[i].front : 0
        let cap = min(29, max(121 - front, 0))
        let amount = Binding<Int>(
            get: { min(max(amounts[i], 1), max(cap, 1)) },
            set: { amounts[i] = $0 }
        )
        let button = Button {
            place(i, 0, front + min(amounts[i], cap))
            amounts[i] = 1
        } label: {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 26))
                .foregroundColor(seatColors[i % 8])
        }
        .buttonStyle(.plain)
        return GeometryReader { box in
            if vertical {
                let wheelH = min(max(box.size.height - 58, 36), 70)
                VStack(spacing: 3) {
                    Text(m.names[i])
                        .font(.caption2.bold())
                        .foregroundColor(GC.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if cap >= 1 {
                        StampWheel(title: "", value: amount, range: 1...cap, width: 56, height: wheelH, seat: i)
                        button
                    } else {
                        Text("Home")
                            .font(.caption.bold())
                            .foregroundColor(GC.dim)
                            .frame(height: wheelH)
                    }
                }
                .frame(width: box.size.width, height: box.size.height)
            } else {
                HStack(spacing: 8) {
                    Text(m.names[i])
                        .font(.caption2.bold())
                        .foregroundColor(GC.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if cap >= 1 {
                        StampWheel(title: "", value: amount, range: 1...cap, width: min(max(box.size.width - 64, 36), 90), height: min(box.size.height, 70), seat: i)
                        button
                    } else {
                        Text("Home")
                            .font(.caption.bold())
                            .foregroundColor(GC.dim)
                    }
                }
                .frame(width: box.size.width, height: box.size.height)
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
