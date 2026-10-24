import SwiftUI

// MARK: Vertical board geometry

/// Each player's 121 holes run in three vertical lanes (up, down, up) like a real board.
func pegSegment(_ idx: Int) -> Int {
    if idx <= 40 { return 0 }
    if idx <= 81 { return 1 }
    return 2
}

let boardRowGap: CGFloat = 24
let boardLaneWidth: CGFloat = 76
let boardTop: CGFloat = 30
let boardBottom: CGFloat = 26
let boardSide: CGFloat = 20

func boardSize(players n: Int, viewWidth: CGFloat) -> CGSize {
    let w = max(viewWidth, CGFloat(n) * boardLaneWidth + 2 * boardSide)
    let h = boardTop + boardBottom + 40 * boardRowGap
    return CGSize(width: w, height: h)
}

func vHolePoint(player: Int, idx: Int, size: CGSize, count n: Int) -> CGPoint {
    let seg = pegSegment(idx)
    var row = 0
    if seg == 0 {
        row = idx
    } else if seg == 1 {
        row = 40 - (idx - 41)
    } else {
        row = idx - 82
    }
    let gw = (size.width - 2 * boardSide) / CGFloat(max(n, 1))
    let cs = min(gw / 3.2, 24)
    let cx = boardSide + gw * (CGFloat(player) + 0.5)
    let dy = (size.height - boardTop - boardBottom) / 40
    return CGPoint(x: cx + CGFloat(seg - 1) * cs, y: size.height - boardBottom - CGFloat(row) * dy)
}

struct VerticalPegBoard: View {
    let names: [String]
    let pegs: [Peg]
    let viewWidth: CGFloat
    let focusPlayer: Int
    let focusHole: Int
    let onPlace: (Int, Int) -> Void

    var body: some View {
        let n = pegs.count
        let size = boardSize(players: n, viewWidth: viewWidth)
        let fp = vHolePoint(player: min(focusPlayer, max(n - 1, 0)), idx: focusHole, size: size, count: n)
        ScrollViewReader { proxy in
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    Canvas { ctx, sz in
                        drawBoard(ctx: &ctx, size: sz)
                    }
                    .frame(width: size.width, height: size.height)
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture().onEnded { value in
                            handleTap(value.location, size: size)
                        }
                    )
                    Color.clear
                        .frame(width: 2, height: 2)
                        .padding(.leading, fp.x)
                        .padding(.top, fp.y)
                        .id("pegfocus")
                        .allowsHitTesting(false)
                }
                .frame(width: size.width, height: size.height)
            }
            .defaultScrollAnchor(.bottom)
            .onChange(of: focusPlayer * 1000 + focusHole) { _, _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo("pegfocus", anchor: .center)
                }
            }
        }
    }

    private func drawBoard(ctx: inout GraphicsContext, size: CGSize) {
        let n = pegs.count
        if n == 0 { return }

        // Lanes, initials top and bottom
        for p in 0..<n {
            let color = seatColors[p % 8]
            let bottomPt = vHolePoint(player: p, idx: 0, size: size, count: n)
            let topPt = vHolePoint(player: p, idx: 40, size: size, count: n)
            let rightPt = vHolePoint(player: p, idx: 82, size: size, count: n)
            let rect = CGRect(
                x: bottomPt.x - 12,
                y: topPt.y - 12,
                width: (rightPt.x - bottomPt.x) + 24,
                height: (bottomPt.y - topPt.y) + 24
            )
            ctx.fill(Path(roundedRect: rect, cornerRadius: 12), with: .color(color.opacity(0.18)))
            let cx = (bottomPt.x + rightPt.x) / 2
            let initials = String(names[p].prefix(3))
            let top = Text(initials)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(color)
            ctx.draw(top, at: CGPoint(x: cx, y: topPt.y - 22))
            let bottom = Text(initials)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(color)
            ctx.draw(bottom, at: CGPoint(x: cx, y: bottomPt.y + 20))
        }

        // Holes
        for p in 0..<n {
            for idx in 0...121 {
                let pt = vHolePoint(player: p, idx: idx, size: size, count: n)
                let special = idx == 61 || idx == 91 || idx == 121
                let r: CGFloat = special ? 5 : 3.5
                let rect = CGRect(x: pt.x - r, y: pt.y - r, width: 2 * r, height: 2 * r)
                let color: Color = special ? Color.red : Color.white.opacity(0.45)
                ctx.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }

        // Scale labels on the outer edges
        for k in [10, 20, 30, 40] {
            let y = vHolePoint(player: 0, idx: k, size: size, count: n).y
            let t = Text("\(k)").font(.system(size: 10)).foregroundColor(GC.dim)
            ctx.draw(t, at: CGPoint(x: 9, y: y))
        }
        for k in [90, 100, 110, 120] {
            let y = vHolePoint(player: 0, idx: k, size: size, count: n).y
            let t = Text("\(k)").font(.system(size: 10)).foregroundColor(GC.dim)
            ctx.draw(t, at: CGPoint(x: size.width - 11, y: y))
        }

        // Connectors and the +N badge between the pegs
        for p in 0..<n {
            let peg = pegs[p]
            let delta = peg.front - peg.back
            if delta <= 0 { continue }
            let pf = vHolePoint(player: p, idx: peg.front, size: size, count: n)
            let pb = vHolePoint(player: p, idx: peg.back, size: size, count: n)
            let color = seatColors[p % 8]
            if pegSegment(peg.front) == pegSegment(peg.back) {
                var line = Path()
                line.move(to: pb)
                line.addLine(to: pf)
                ctx.stroke(line, with: .color(color.opacity(0.75)), lineWidth: 4)
            }
            let mid = CGPoint(x: (pf.x + pb.x) / 2 + 22, y: (pf.y + pb.y) / 2)
            let badge = CGRect(x: mid.x - 17, y: mid.y - 10, width: 34, height: 20)
            ctx.fill(Path(roundedRect: badge, cornerRadius: 10), with: .color(color))
            ctx.stroke(Path(roundedRect: badge, cornerRadius: 10), with: .color(Color.white), lineWidth: 1.5)
            let text = Text("+\(delta)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color.white)
            ctx.draw(text, at: mid)
        }

        // Pegs
        for p in 0..<n {
            let peg = pegs[p]
            let color = seatColors[p % 8]
            let pf = vHolePoint(player: p, idx: peg.front, size: size, count: n)
            let pb = vHolePoint(player: p, idx: peg.back, size: size, count: n)
            if peg.back != peg.front {
                let br: CGFloat = 7.5
                let brect = CGRect(x: pb.x - br, y: pb.y - br, width: 2 * br, height: 2 * br)
                ctx.fill(Path(ellipseIn: brect), with: .color(color.opacity(0.55)))
                ctx.stroke(Path(ellipseIn: brect), with: .color(Color.white), lineWidth: 1.5)
            }
            let fr: CGFloat = 10
            let frect = CGRect(x: pf.x - fr, y: pf.y - fr, width: 2 * fr, height: 2 * fr)
            ctx.fill(Path(ellipseIn: frect), with: .color(color))
            ctx.stroke(Path(ellipseIn: frect), with: .color(Color.white), lineWidth: 2)
        }
    }

    private func handleTap(_ pt: CGPoint, size: CGSize) {
        let n = pegs.count
        if n == 0 { return }
        var bestP = 0
        var bestIdx = 0
        var bestD = CGFloat.greatestFiniteMagnitude
        for p in 0..<n {
            for idx in 0...121 {
                let h = vHolePoint(player: p, idx: idx, size: size, count: n)
                let dx = h.x - pt.x
                let dy = h.y - pt.y
                let d = dx * dx + dy * dy
                if d < bestD {
                    bestD = d
                    bestP = p
                    bestIdx = idx
                }
            }
        }
        if bestD < 40 * 40 {
            onPlace(bestP, bestIdx)
        }
    }
}

struct CribbageBoardView: View {
    let matchID: UUID
    @EnvironmentObject var store: Store
    @State private var selected = 0
    @State private var amount = 1
    @State private var focusHole = 0

    private var match: GameMatch? {
        return store.matches.first { $0.id == matchID }
    }

    var body: some View {
        if let m = match {
            VStack(spacing: 6) {
                GeometryReader { geo in
                    VerticalPegBoard(
                        names: m.names,
                        pegs: m.pegs,
                        viewWidth: geo.size.width,
                        focusPlayer: selected,
                        focusHole: focusHole
                    ) { p, hole in
                        selected = p
                        focusHole = hole
                        place(p, hole)
                    }
                }
                if !m.finished {
                    controls(m)
                }
            }
        }
    }

    private func controls(_ m: GameMatch) -> some View {
        let sel = min(selected, max(m.names.count - 1, 0))
        let front = sel < m.pegs.count ? m.pegs[sel].front : 0
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
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.15)))
            }
            StampWheel(title: "", value: $amount, range: 1...29, width: 60, height: 78)
            Button("Peg +\(amount)") {
                let target = min(front + amount, 121)
                focusHole = target
                place(sel, target)
            }
            .buttonStyle(GlossButtonStyle(compact: true))
            Spacer(minLength: 0)
            Button {
                undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.title3)
            }
            .foregroundColor(.white)
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
                    .foregroundColor(.white)
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
