import SwiftUI

// MARK: Board geometry
// Every player has ONE long vertical lane of 121 holes (0 is the start, at the bottom).
// Lanes sit side by side and are always scaled to the full width, so every peg is on screen.

struct BoardGeo {
    let size: CGSize
    let count: Int
    let top: CGFloat = 30
    let bottom: CGFloat = 30
    let side: CGFloat = 4

    var laneWidth: CGFloat {
        return (size.width - 2 * side) / CGFloat(max(count, 1))
    }

    var rowGap: CGFloat {
        return (size.height - top - bottom) / 121
    }

    func laneCenter(_ p: Int) -> CGFloat {
        return side + laneWidth * (CGFloat(p) + 0.5)
    }

    func holeX(_ p: Int) -> CGFloat {
        return laneCenter(p) + min(laneWidth * 0.12, 6)
    }

    func holeY(_ idx: Int) -> CGFloat {
        return size.height - bottom - CGFloat(idx) * rowGap
    }

    func point(_ p: Int, _ idx: Int) -> CGPoint {
        return CGPoint(x: holeX(p), y: holeY(idx))
    }

    func hole(forY y: CGFloat) -> Int {
        let raw = ((size.height - bottom - y) / max(rowGap, 0.1)).rounded()
        return min(max(Int(raw), 0), 121)
    }

    func lane(forX x: CGFloat) -> Int {
        let raw = Int(((x - side) / max(laneWidth, 1)).rounded(.down))
        return min(max(raw, 0), max(count - 1, 0))
    }
}

/// The draggable front peg of one player.
struct PegHandle: View {
    let color: Color
    let position: CGPoint
    let selected: Bool
    let onChange: (CGPoint) -> Void
    let onEnd: (CGPoint) -> Void

    var body: some View {
        Circle()
            .fill(color)
            .overlay(Circle().stroke(GC.base, lineWidth: 2))
            .overlay(Circle().stroke(GC.text, lineWidth: selected ? 1.5 : 0).padding(-3))
            .frame(width: 17, height: 17)
            .frame(width: 38, height: 38)
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
    let preview: Int            // holes the wheel would add for the selected player
    let zoomed: Bool
    let onSelect: (Int) -> Void
    let onPlace: (Int, Int) -> Void

    @State private var dragPlayer: Int? = nil
    @State private var dragHole: Int = 0
    @State private var dragPoint: CGPoint = .zero

    var body: some View {
        GeometryReader { geo in
            let z: CGFloat = zoomed ? 2.4 : 1.0
            let size = CGSize(width: geo.size.width, height: geo.size.height * z)
            let g = BoardGeo(size: size, count: pegs.count)
            ScrollView(.vertical, showsIndicators: zoomed) {
                ZStack(alignment: .topLeading) {
                    Canvas { ctx, sz in
                        drawBoard(ctx: &ctx, g: g)
                    }
                    .frame(width: size.width, height: size.height)

                    ForEach(0..<pegs.count, id: \.self) { p in
                        gainBadge(p, g)
                    }

                    ForEach(0..<pegs.count, id: \.self) { p in
                        pegViews(p, g)
                    }

                    if let p = dragPlayer, p < pegs.count {
                        loupe(p, g)
                    }
                }
                .frame(width: size.width, height: size.height)
                .coordinateSpace(name: "board")
            }
            .defaultScrollAnchor(.bottom)
            .scrollBounceBehavior(.basedOnSize)
            .scrollDisabled(dragPlayer != nil)
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
        return ZStack {
            if delta > 0 {
                Path { path in
                    path.move(to: a)
                    path.addLine(to: b)
                }
                .stroke(color.opacity(0.55), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                Text("+\(delta)")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(GC.base)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(color))
                    .position(x: g.laneCenter(p) - min(g.laneWidth * 0.28, 8), y: (a.y + b.y) / 2)
            }
        }
        .allowsHitTesting(false)
    }

    private func pegViews(_ p: Int, _ g: BoardGeo) -> some View {
        let color = seatColors[p % 8]
        let peg = pegs[p]
        let backPt = g.point(p, peg.back)
        let frontPt = g.point(p, frontHole(p))
        return ZStack {
            if peg.back != peg.front {
                Circle()
                    .fill(color.opacity(0.6))
                    .overlay(Circle().stroke(GC.base, lineWidth: 1))
                    .frame(width: 11, height: 11)
                    .position(backPt)
                    .allowsHitTesting(false)
            }
            if selected == p && preview > 0 && dragPlayer == nil && peg.front + preview <= 121 {
                let ghost = g.point(p, peg.front + preview)
                Circle()
                    .strokeBorder(color, style: StrokeStyle(lineWidth: 2, dash: [3, 2]))
                    .frame(width: 17, height: 17)
                    .position(ghost)
                    .allowsHitTesting(false)
            }
            PegHandle(
                color: color,
                position: frontPt,
                selected: selected == p,
                onChange: { pt in
                    if dragPlayer == nil {
                        dragPlayer = p
                        onSelect(p)
                    }
                    dragHole = g.hole(forY: pt.y)
                    dragPoint = pt
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
        let x = min(max(g.holeX(p), 44), g.size.width - 44)
        let y = max(g.holeY(dragHole) - 58, 26)
        return VStack(spacing: 0) {
            Text("\(dragHole)")
                .font(.system(size: 22, weight: .heavy, design: .serif))
                .foregroundColor(GC.base)
            Text(note)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(GC.base.opacity(0.85))
        }
        .frame(width: 72, height: 44)
        .background(RoundedRectangle(cornerRadius: 12).fill(color))
        .position(x: x, y: y)
        .allowsHitTesting(false)
    }

    private func drawBoard(ctx: inout GraphicsContext, g: BoardGeo) {
        let n = pegs.count
        if n == 0 { return }
        let gap = g.rowGap
        let dot = min(gap * 0.38, 2.4)

        for p in 0..<n {
            let color = seatColors[p % 8]
            let x0 = g.side + g.laneWidth * CGFloat(p) + 2
            let rect = CGRect(x: x0, y: g.holeY(121) - 12, width: g.laneWidth - 4, height: g.holeY(0) - g.holeY(121) + 24)
            let isSel = selected == p
            ctx.fill(Path(roundedRect: rect, cornerRadius: 10), with: .color(color.opacity(isSel ? 0.26 : 0.14)))
            ctx.stroke(Path(roundedRect: rect, cornerRadius: 10), with: .color(color.opacity(isSel ? 1.0 : 0.5)), lineWidth: isSel ? 2 : 1)

            let initials = String(names[p].prefix(3))
            let label = Text(initials)
                .font(.system(size: 12, weight: .heavy, design: .serif))
                .foregroundColor(GC.text)
            ctx.draw(label, at: CGPoint(x: g.laneCenter(p), y: g.holeY(121) - 20))
            ctx.draw(label, at: CGPoint(x: g.laneCenter(p), y: g.holeY(0) + 20))

            for idx in 0...121 {
                let pt = g.point(p, idx)
                let special = idx == 61 || idx == 91 || idx == 121
                let five = idx % 5 == 0
                let r: CGFloat = special ? dot * 1.5 : (five ? dot * 1.25 : dot)
                let rect = CGRect(x: pt.x - r, y: pt.y - r, width: 2 * r, height: 2 * r)
                var c: Color = five ? GC.dim : GC.overlay
                if special { c = GC.red }
                ctx.fill(Path(ellipseIn: rect), with: .color(c))
            }

            // Scale numbers along the left of each lane (every 20, plus the finish)
            for k in [20, 40, 60, 80, 100, 121] {
                let t = Text("\(k)")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(GC.dim)
                ctx.draw(t, at: CGPoint(x: g.holeX(p) - min(g.laneWidth * 0.34, 14), y: g.holeY(k)))
            }
        }
    }
}

struct CribbageBoardView: View {
    let matchID: UUID
    @EnvironmentObject var store: Store
    @State private var selected = 0
    @State private var amount = 1
    @State private var zoomed = false

    private var match: GameMatch? {
        return store.matches.first { $0.id == matchID }
    }

    var body: some View {
        if let m = match {
            VStack(spacing: 8) {
                PegBoard(
                    names: m.names,
                    pegs: m.pegs,
                    selected: min(selected, max(m.names.count - 1, 0)),
                    preview: m.finished ? 0 : amount,
                    zoomed: zoomed,
                    onSelect: { p in selected = p },
                    onPlace: { p, hole in
                        selected = p
                        place(p, hole)
                    }
                )
                if !m.finished {
                    controls(m)
                }
            }
        }
    }

    private func controls(_ m: GameMatch) -> some View {
        let sel = min(selected, max(m.names.count - 1, 0))
        let front = sel < m.pegs.count ? m.pegs[sel].front : 0
        let room = max(121 - front, 0)
        let cap = min(29, room)
        return HStack(spacing: 8) {
            Menu {
                ForEach(0..<m.names.count, id: \.self) { i in
                    Button(m.names[i]) {
                        selected = i
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Circle()
                        .fill(seatColors[sel % 8])
                        .frame(width: 12, height: 12)
                    Text(m.names[sel])
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
                .font(.subheadline)
                .foregroundColor(GC.text)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Capsule().fill(GC.surface0))
                .overlay(Capsule().stroke(seatColors[sel % 8], lineWidth: 1.5))
            }
            if cap >= 1 {
                StampWheel(title: "", value: $amount, range: 1...cap, width: 70, height: 76, seat: sel)
                Button("Peg +\(min(amount, cap))") {
                    place(sel, front + min(amount, cap))
                }
                .buttonStyle(GlossButtonStyle(compact: true))
            } else {
                Text("At the finish")
                    .font(.subheadline.bold())
                    .foregroundColor(GC.dim)
            }
            Spacer(minLength: 0)
            Button {
                zoomed.toggle()
            } label: {
                Image(systemName: zoomed ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.title3)
            }
            .foregroundColor(GC.text)
            Button {
                undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.title3)
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
