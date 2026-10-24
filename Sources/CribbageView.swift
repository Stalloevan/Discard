import SwiftUI

// MARK: Vertical board geometry

/// Each player's 121 holes run in three vertical lanes (up, down, up) like a real board.
func pegSegment(_ idx: Int) -> Int {
    if idx <= 40 { return 0 }
    if idx <= 81 { return 1 }
    return 2
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
    let sideMargin: CGFloat = 20
    let top: CGFloat = 22
    let bottom: CGFloat = 8
    let gw = (size.width - 2 * sideMargin) / CGFloat(max(n, 1))
    let cs = min(gw / 3.2, 18)
    let cx = sideMargin + gw * (CGFloat(player) + 0.5)
    let dy = (size.height - top - bottom) / 40
    return CGPoint(x: cx + CGFloat(seg - 1) * cs, y: size.height - bottom - CGFloat(row) * dy)
}

struct VerticalPegBoard: View {
    let names: [String]
    let pegs: [Peg]
    let onPlace: (Int, Int) -> Void

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let n = pegs.count
                if n == 0 { return }

                // Lane backgrounds and initials
                for p in 0..<n {
                    let a = vHolePoint(player: p, idx: 0, size: size, count: n)
                    let b = vHolePoint(player: p, idx: 40, size: size, count: n)
                    let left = vHolePoint(player: p, idx: 0, size: size, count: n).x
                    let right = vHolePoint(player: p, idx: 82, size: size, count: n).x
                    let rect = CGRect(x: left - 8, y: b.y - 10, width: (right - left) + 16, height: (a.y - b.y) + 20)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 8), with: .color(seatColors[p % 8].opacity(0.16)))
                    let label = Text(String(names[p].prefix(3)))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(seatColors[p % 8])
                    ctx.draw(label, at: CGPoint(x: (left + right) / 2, y: b.y - 18))
                }

                // Holes
                for p in 0..<n {
                    for idx in 0...121 {
                        let pt = vHolePoint(player: p, idx: idx, size: size, count: n)
                        let special = idx == 61 || idx == 91 || idx == 121
                        let r: CGFloat = special ? 3.2 : 2.2
                        let rect = CGRect(x: pt.x - r, y: pt.y - r, width: 2 * r, height: 2 * r)
                        let color: Color = special ? Color.red : Color.white.opacity(0.4)
                        ctx.fill(Path(ellipseIn: rect), with: .color(color))
                    }
                }

                // Scale labels on the outer edges
                for k in [10, 20, 30, 40] {
                    let y = vHolePoint(player: 0, idx: k, size: size, count: n).y
                    let t = Text("\(k)").font(.system(size: 8)).foregroundColor(GC.dim)
                    ctx.draw(t, at: CGPoint(x: 8, y: y))
                }
                for k in [90, 100, 110, 120] {
                    let y = vHolePoint(player: 0, idx: k, size: size, count: n).y
                    let t = Text("\(k)").font(.system(size: 8)).foregroundColor(GC.dim)
                    ctx.draw(t, at: CGPoint(x: size.width - 8, y: y))
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
                        ctx.stroke(line, with: .color(color.opacity(0.7)), lineWidth: 3)
                    }
                    let mid = CGPoint(x: (pf.x + pb.x) / 2 + 15, y: (pf.y + pb.y) / 2)
                    let badge = CGRect(x: mid.x - 12, y: mid.y - 7, width: 24, height: 14)
                    ctx.fill(Path(roundedRect: badge, cornerRadius: 7), with: .color(color))
                    ctx.stroke(Path(roundedRect: badge, cornerRadius: 7), with: .color(Color.white), lineWidth: 1)
                    let text = Text("+\(delta)")
                        .font(.system(size: 9, weight: .bold))
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
                        ctx.fill(Path(ellipseIn: brect), with: .color(color.opacity(0.55)))
                        ctx.stroke(Path(ellipseIn: brect), with: .color(Color.white), lineWidth: 1)
                    }
                    let fr: CGFloat = 6
                    let frect = CGRect(x: pf.x - fr, y: pf.y - fr, width: 2 * fr, height: 2 * fr)
                    ctx.fill(Path(ellipseIn: frect), with: .color(color))
                    ctx.stroke(Path(ellipseIn: frect), with: .color(Color.white), lineWidth: 1.5)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture().onEnded { value in
                    handleTap(value.location, size: geo.size)
                }
            )
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
        if bestD < 30 * 30 {
            onPlace(bestP, bestIdx)
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
            VStack(spacing: 6) {
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
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.15)))
            }
            Picker("Points", selection: $amount) {
                ForEach(1...29, id: \.self) { n in
                    Text("\(n)").tag(n)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 60, height: 66)
            .clipped()
            .environment(\.colorScheme, .dark)
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
