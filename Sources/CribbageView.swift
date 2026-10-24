import SwiftUI

struct CribbageView: View {
    let matchID: UUID
    @EnvironmentObject var store: Store
    @State private var amount: [Int] = Array(repeating: 1, count: 8)

    private var match: GameMatch? {
        return store.matches.first { $0.id == matchID }
    }

    var body: some View {
        if let m = match {
            Section {
                Text("Tap a hole to place a player's front peg. The old front peg becomes the back peg and the points between them show on the board. Red holes mark 61, 91 and 121.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(0..<m.units.count, id: \.self) { u in
                playerBoard(m, u)
            }

            if !m.finished {
                Section {
                    Button {
                        undo()
                    } label: {
                        Label("Undo last peg move", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(m.pegHistory.isEmpty)
                    Button(role: .destructive) {
                        resetBoard()
                    } label: {
                        Label("Reset the board", systemImage: "arrow.counterclockwise")
                    }
                }
            }
        }
    }

    private func playerBoard(_ m: GameMatch, _ u: Int) -> some View {
        let p = u < m.pegs.count ? m.pegs[u] : Peg()
        let isDealer = m.dealer == u
        return Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Front \(p.front) · Back \(p.back)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if p.front > p.back {
                        Text("+\(p.front - p.back)")
                            .font(.subheadline.bold())
                            .foregroundStyle(seatColors[u % 8])
                    }
                }
                PegBoard(peg: p, color: seatColors[u % 8]) { hole in
                    place(u, hole)
                }
                if !m.finished {
                    HStack {
                        Picker("Points", selection: $amount[u]) {
                            ForEach(1...29, id: \.self) { n in
                                Text("\(n)").tag(n)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 90, height: 80)
                        .clipped()
                        Button {
                            place(u, min(p.front + amount[u], 121))
                        } label: {
                            Label("Peg +\(amount[u])", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            HStack(spacing: 6) {
                Circle()
                    .fill(seatColors[u % 8])
                    .frame(width: 10, height: 10)
                Text(m.names[u])
                if isDealer {
                    Text("DEALER · CRIB")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.secondary.opacity(0.25)))
                }
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
