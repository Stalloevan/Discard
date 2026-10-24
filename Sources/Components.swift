import SwiftUI

let seatColors: [Color] = [.blue, .red, .green, .orange, .purple, .teal, .pink, .brown]

func signed(_ n: Int) -> String {
    return n > 0 ? "+\(n)" : "\(n)"
}

struct WheelColumn: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption)
                .lineLimit(1)
                .frame(width: 72)
            Picker(title, selection: $value) {
                ForEach(Array(range), id: \.self) { n in
                    Text("\(n)").tag(n)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 72, height: 110)
            .clipped()
        }
    }
}

// MARK: Cribbage peg board drawing

func holePoint(_ idx: Int, width: CGFloat) -> CGPoint {
    let perRow = 31
    var row = idx / perRow
    if row > 3 { row = 3 }
    let col = idx - row * perRow
    let c = row % 2 == 0 ? col : (perRow - 1 - col)
    let margin: CGFloat = 14
    let dx = (width - 2 * margin) / CGFloat(perRow - 1)
    return CGPoint(x: margin + CGFloat(c) * dx, y: 18 + CGFloat(row) * 34)
}

func nearestHole(_ pt: CGPoint, width: CGFloat) -> Int {
    var best = 0
    var bestD = CGFloat.greatestFiniteMagnitude
    for idx in 0...121 {
        let p = holePoint(idx, width: width)
        let dx = p.x - pt.x
        let dy = p.y - pt.y
        let d = dx * dx + dy * dy
        if d < bestD {
            bestD = d
            best = idx
        }
    }
    return best
}

struct PegBoard: View {
    let peg: Peg
    let color: Color
    let onPlace: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let width = size.width
                for idx in 0...121 {
                    let p = holePoint(idx, width: width)
                    let special = idx == 61 || idx == 91 || idx == 121
                    let r: CGFloat = special ? 4.5 : 3
                    let rect = CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)
                    let holeColor: Color = special ? Color.red : Color.gray.opacity(0.6)
                    ctx.fill(Path(ellipseIn: rect), with: .color(holeColor))
                    if idx % 10 == 0 && idx > 0 {
                        let label = Text("\(idx)")
                            .font(.system(size: 8))
                            .foregroundColor(Color.secondary)
                        ctx.draw(label, at: CGPoint(x: p.x, y: p.y + 12))
                    }
                }

                let pf = holePoint(peg.front, width: width)
                let pb = holePoint(peg.back, width: width)
                let delta = peg.front - peg.back
                let sameRow = abs(pf.y - pb.y) < 1

                if delta > 0 && sameRow {
                    var line = Path()
                    line.move(to: pb)
                    line.addLine(to: pf)
                    ctx.stroke(line, with: .color(color.opacity(0.45)), lineWidth: 3)
                }

                if delta > 0 {
                    let mid: CGPoint
                    if sameRow {
                        mid = CGPoint(x: (pf.x + pb.x) / 2, y: pf.y - 13)
                    } else {
                        mid = CGPoint(x: pf.x, y: pf.y - 13)
                    }
                    let badge = CGRect(x: mid.x - 16, y: mid.y - 8, width: 32, height: 16)
                    ctx.fill(Path(roundedRect: badge, cornerRadius: 8), with: .color(color))
                    let text = Text("+\(delta)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.white)
                    ctx.draw(text, at: mid)
                }

                if peg.back != peg.front {
                    let br: CGFloat = 5.5
                    let brect = CGRect(x: pb.x - br, y: pb.y - br, width: 2 * br, height: 2 * br)
                    ctx.fill(Path(ellipseIn: brect), with: .color(color.opacity(0.55)))
                    ctx.stroke(Path(ellipseIn: brect), with: .color(Color.white), lineWidth: 1)
                }
                let fr: CGFloat = 7
                let frect = CGRect(x: pf.x - fr, y: pf.y - fr, width: 2 * fr, height: 2 * fr)
                ctx.fill(Path(ellipseIn: frect), with: .color(color))
                ctx.stroke(Path(ellipseIn: frect), with: .color(Color.white), lineWidth: 1.5)
            }
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture().onEnded { value in
                    onPlace(nearestHole(value.location, width: geo.size.width))
                }
            )
        }
        .frame(height: 138)
    }
}
