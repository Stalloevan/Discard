import SwiftUI

struct WarPanel: View {
    let matchID: UUID
    @EnvironmentObject var store: Store

    private var match: GameMatch? {
        return store.matches.first { $0.id == matchID }
    }

    private func binding(_ i: Int) -> Binding<Int> {
        return Binding<Int>(
            get: {
                if let m = match, i < m.cards.count { return m.cards[i] }
                return 0
            },
            set: { newValue in
                store.mutate(matchID) { m in
                    if i >= m.cards.count { return }
                    var others = 0
                    for (j, c) in m.cards.enumerated() where j != i {
                        others += c
                    }
                    let cap = GameRules.warPer(m.names.count) * m.names.count
                    m.cards[i] = max(0, min(newValue, cap - others))
                }
            }
        )
    }

    var body: some View {
        if let m = match {
            let total = GameRules.warPer(m.names.count) * m.names.count
            let held = m.cards.reduce(0, +)
            VStack(spacing: 8) {
                HStack {
                    Text("Cards held")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(held) / \(total)")
                        .font(.subheadline.bold())
                        .foregroundColor(held == total ? Color.green : GC.gold)
                        .monospacedDigit()
                }
                WheelRow(
                    titles: m.names,
                    values: (0..<m.names.count).map { i in binding(i) },
                    ranges: (0..<m.names.count).map { i in remainingRange(m.cards, i, cap: total) }
                )
                HStack {
                    let out = m.names.indices.filter { m.cards[$0] == 0 }.map { m.names[$0] }
                    Text(out.isEmpty ? "Set each player's count after every battle." : "Out: " + out.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(GC.dim)
                        .lineLimit(2)
                    Spacer()
                    Button("Reset") {
                        store.mutate(matchID) { mm in
                            mm.cards = Array(repeating: GameRules.warPer(mm.names.count), count: mm.names.count)
                        }
                    }
                    .buttonStyle(GlossButtonStyle(tint: Color.gray, compact: true))
                }
            }
        }
    }
}
