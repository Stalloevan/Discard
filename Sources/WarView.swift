import SwiftUI

struct WarView: View {
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
                    if i < m.cards.count { m.cards[i] = newValue }
                }
            }
        )
    }

    var body: some View {
        if let m = match {
            let total = GameRules.warPer(m.names.count) * m.names.count
            let held = m.cards.reduce(0, +)
            Section("Set each player's card count") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<m.names.count, id: \.self) { i in
                            WheelColumn(title: m.names[i], value: binding(i), range: 0...total)
                        }
                    }
                }
                HStack {
                    Text("Cards counted")
                    Spacer()
                    Text("\(held) of \(total)")
                        .foregroundStyle(held == total ? Color.green : Color.orange)
                        .monospacedDigit()
                }
                let out = m.names.indices.filter { m.cards[$0] == 0 }.map { m.names[$0] }
                if !out.isEmpty {
                    Text("Out: " + out.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Button(role: .destructive) {
                    store.mutate(matchID) { mm in
                        mm.cards = Array(repeating: GameRules.warPer(mm.names.count), count: mm.names.count)
                    }
                } label: {
                    Label("Reset to the starting deal", systemImage: "arrow.counterclockwise")
                }
            }
        }
    }
}
