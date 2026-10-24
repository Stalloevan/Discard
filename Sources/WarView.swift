import SwiftUI

struct WarPanel: View {
    let matchID: UUID
    @EnvironmentObject var store: Store

    private var match: GameMatch? {
        return store.matches.first { $0.id == matchID }
    }

    var body: some View {
        if let m = match {
            let total = GameRules.warPer(m.names.count) * m.names.count
            let held = m.cards.reduce(0, +)
            VStack(spacing: 8) {
                HStack {
                    Text("Cards held by each player")
                        .font(.subheadline)
                        .foregroundColor(GC.dim)
                    Spacer()
                    Text("\(held) / \(total)")
                        .font(.subheadline.bold())
                        .foregroundColor(held == total ? Color.green : GC.gold)
                        .monospacedDigit()
                }
                DrumPad(
                    titles: m.names,
                    fieldNames: ["Cards"],
                    values: Binding<[[Int]]>(
                        get: { [m.cards] },
                        set: { newValue in
                            store.mutate(matchID) { mm in
                                if let first = newValue.first, first.count == mm.cards.count {
                                    mm.cards = first
                                }
                            }
                        }
                    ),
                    ranges: { _, u in remainingRange(m.cards, u, cap: total) },
                    summary: { u in "\(m.cards[u])" },
                    info: { _ in
                        let out = m.names.indices.filter { m.cards[$0] == 0 }.map { m.names[$0] }
                        return out.isEmpty ? "Move cards after every battle." : "Out: " + out.joined(separator: ", ")
                    }
                )
                Button("Reset to the starting deal") {
                    store.mutate(matchID) { mm in
                        mm.cards = Array(repeating: GameRules.warPer(mm.names.count), count: mm.names.count)
                    }
                }
                .buttonStyle(GlossButtonStyle(tint: Color.gray, compact: true))
            }
        }
    }
}
