import SwiftUI

// MARK: Board geometry
// Every player has one track of two vertical lanes: holes 0-60 run up the left lane,
// holes 61-121 run back down the right lane. The whole board always fits on screen.

func laneOf(_ idx: Int) -> Int {
    return idx <= 60 ? 0 : 1
}

let boardSide: CGFloat = 22
let boardTop: CGFloat = 34
let boardBottom: CGFloat = 34

func vHolePoint(player: Int, idx: Int, size: CGSize, count n: Int) -> CGPoint {
    let lane = laneOf(idx)
    let row = lane == 0 ? idx : 60 - (idx - 61)
    let gw = (size.width - 2 * boardSide) / CGFloat(max(n, 1))
    let cs = min(gw * 0.5, 34)
    let cx = boardSide + gw * (CGFloat(player) + 0.5)
    let dy = (size.height - boardTop - boardBottom) / 60
    let x = cx + (lane == 0 ? -cs / 2 : cs / 2)
    return CGPoint(x: x, y: size.height - boardBottom - CGFloat(row) * dy)
}

struct VerticalPegBoard: View {
    let names: [String]
    let pegs: [Peg]
    let onPlace: (Int, Int) -> Void

    @State private var dragPlayer: Int? = nil
    @State private var dragHole: Int = 0
    @State private var dragPoint: CGPoint = .zero

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                drawBoard(ctx: &ctx, size: size)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        track(value.location, size: geo.size)
                    }
                    .onEnded { value in
                        track(value.location, size: geo.size)
                        if let p = dragPlayer {
                            onPlace(p, dragHole)
                        }
                        dragPlayer = nil
                    }
            )
        }
    }

    private func nearestPlayer(_ x: CGFloat, size: CGSize) -> Int {
        let n = max(pegs.count, 1)
        let gw = (size.width - 2 * boardSide) / CGFloat(n)
        let raw = Int(((x - boardSide) / gw).rounded(.down))
        return min(max(raw, 0), n - 1)
    }

    private func nearestHole(_ p: Int, _ pt: CGPoint, size: CGSize) -> Int {
        var best = 0
        var bestD = CGFloat.greatestFiniteMagnitude
        for idx in 0...121 {
            let h = vHolePoint(player: p, idx: idx, size: size, count: pegs.count)
            let dx = h.x - pt.x
            let dy = h.y - pt.y
            let d = dx * dx + dy * dy
            if d < bestD {
                bestD = d
                best = idx
            }
        }
        return best
    }

    private func track(_ pt: CGPoint, size: CGSize) {
        if pegs.isEmpty { return }
        if dragPlayer == nil {
            dragPlayer = nearestPlayer(pt.x, size: size)
        }
        if let p = dragPlayer {
            dragHole = nearestHole(p, pt, size: size)
            dragPoint = pt
        }
    }

    private func drawBoard(ctx: inout GraphicsContext, size: CGSize) {
        let n = pegs.count
        if n == 0 { return }

        // Lanes and initials
        for p in 0..<n {
            let color = seatColors[p % 8]
            let a = vHolePoint(player: p, idx: 0, size: size, count: n)
            let b = vHolePoint(player: p, idx: 121, size: size, count: n)
            let topY = vHolePoint(player: p, idx: 60, size: size, count: n).y
            let rect = CGRect(x: a.x - 12, y: topY - 12, width: (b.x - a.x) + 24, height: (a.y - topY) + 24)
            ctx.fill(Path(roundedRect: rect, cornerRadius: 12), with: .color(color.opacity(0.2)))
            ctx.stroke(Path(roundedRect: rect, cornerRadius: 12), with: .color(color.opacity(0.6)), lineWidth: 1)
            let cx = (a.x + b.x) / 2
            let initials = String(names[p].prefix(3))
            let label = Text(initials)
                .font(.system(size: 13, weight: .heavy, design: .serif))
                .foregroundColor(color)
            ctx.draw(label, at: CGPoint(x: cx, y: topY - 24))
            ctx.draw(label, at: CGPoint(x: cx, y: a.y + 24))
        }

        // Holes
        for p in 0..<n {
            let sel = dragPlayer == p
            for idx in 0...121 {
                let pt = vHolePoint(player: p, idx: idx, size: size, count: n)
                let special = idx == 61 || idx == 91 || idx == 121
                let r: CGFloat = special ? 3.2 : (idx % 5 == 0 ? 2.6 : 1.9)
                let rect = CGRect(x: pt.x - r, y: pt.y - r, width: 2 * r, height: 2 * r)
                var color: Color = Color.white.opacity(sel ? 0.7 : 0.42)
                if special { color = Color.red }
                ctx.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }

        // Scale along the outer edges (every 10)
        for k in stride(from: 10, through: 60, by: 10) {
            let y = vHolePoint(player: 0, idx: k, size: size, count: n).y
            let t = Text("\(k)").font(.system(size: 9)).foregroundColor(GC.dim)
            ctx.draw(t, at: CGPoint(x: 9, y: y))
        }
        for k in stride(from: 70, through: 120, by: 10) {
            let y = vHolePoint(player: 0, idx: k, size: size, count: n).y
            let t = Text("\(k)").font(.system(size: 9)).foregroundColor(GC.dim)
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
            if laneOf(peg.front) == laneOf(peg.back) {
                var line = Path()
                line.move(to: pb)
                line.addLine(to: pf)
                ctx.stroke(line, with: .color(color.opacity(0.8)), lineWidth: 4)
            }
            let mid = CGPoint(x: (pf.x + pb.x) / 2, y: (pf.y + pb.y) / 2)
            let badge = CGRect(x: mid.x - 15, y: mid.y - 9, width: 30, height: 18)
            ctx.fill(Path(roundedRect: badge, cornerRadius: 9), with: .color(color))
            ctx.stroke(Path(roundedRect: badge, cornerRadius: 9), with: .color(Color.white), lineWidth: 1.5)
            let text = Text("+\(delta)")
                .font(.system(size: 11, weight: .heavy))
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
                let br: CGFloat = 4.5
                let brect = CGRect(x: pb.x - br, y: pb.y - br, width: 2 * br, height: 2 * br)
                ctx.fill(Path(ellipseIn: brect), with: .color(color.opacity(0.6)))
                ctx.stroke(Path(ellipseIn: brect), with: .color(Color.white), lineWidth: 1)
            }
            let fr: CGFloat = 6.5
            let frect = CGRect(x: pf.x - fr, y: pf.y - fr, width: 2 * fr, height: 2 * fr)
            ctx.fill(Path(ellipseIn: frect), with: .color(color))
            ctx.stroke(Path(ellipseIn: frect), with: .color(Color.white), lineWidth: 1.5)
        }

        // While dragging: ghost ring on the hole and a loupe above the finger
        if let p = dragPlayer, p < n {
            let color = seatColors[p % 8]
            let h = vHolePoint(player: p, idx: dragHole, size: size, count: n)
            let ring = CGRect(x: h.x - 9, y: h.y - 9, width: 18, height: 18)
            ctx.stroke(Path(ellipseIn: ring), with: .color(Color.white), lineWidth: 2.5)
            ctx.stroke(Path(ellipseIn: ring.insetBy(dx: 3, dy: 3)), with: .color(color), lineWidth: 2)

            let gain = max(dragHole - pegs[p].front, 0)
            let loupeX = min(max(dragPoint.x, 44), size.width - 44)
            let loupeY = max(dragPoint.y - 64, 26)
            let loupe = CGRect(x: loupeX - 36, y: loupeY - 22, width: 72, height: 44)
            ctx.fill(Path(roundedRect: loupe, cornerRadius: 12), with: .color(Color.black.opacity(0.85)))
            ctx.stroke(Path(roundedRect: loupe, cornerRadius: 12), with: .color(color), lineWidth: 2.5)
            let big = Text("\(dragHole)")
                .font(.system(size: 22, weight: .heavy, design: .serif))
                .foregroundColor(Color.white)
            ctx.draw(big, at: CGPoint(x: loupeX, y: loupeY - 5))
            let note = gain > 0 ? "+\(gain)" : (dragHole == pegs[p].front ? "stay" : "back")
            let small = Text(note)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(GC.gold)
            ctx.draw(small, at: CGPoint(x: loupeX, y: loupeY + 13))
        }
    }
}

struct CribbageBoardView: View {
    let matchID: UUID
    @EnvironmentObject var store: Store
    @State private var selected = 0
    @State private var amount = 1

    private var match: GameMatch? {
        return store.matches.first { $0.id == matchID }
    }

    var body: some View {
        if let m = match {
            VStack(spacing: 8) {
                VerticalPegBoard(names: m.names, pegs: m.pegs) { p, hole in
                    selected = p
                    place(p, hole)
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
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.black.opacity(0.3)))
                .overlay(Capsule().stroke(seatColors[sel % 8], lineWidth: 1.5))
            }
            StampWheel(title: "", value: $amount, range: 1...29, width: 70, height: 76)
            Button("Peg +\(amount)") {
                place(sel, min(front + amount, 121))
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
