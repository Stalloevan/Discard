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
            VStack(spacing: 4) {
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
                    },
                    onReset: {
                        store.mutate(matchID) { mm in
                            mm.cards = Array(repeating: GameRules.warPer(mm.names.count), count: mm.names.count)
                        }
                    },
                    status: "\(held) / \(total)",
                    statusColor: held == total ? GC.green : GC.dim
                )
            }
        }
    }
}
