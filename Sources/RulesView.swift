import SwiftUI

/// Rules live behind the book icon. Shown full screen with our own header.
struct RulesSheet: View {
    let kind: GameKind
    let players: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            GCHeader("\(kind.title) rules", showBack: false) {
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .foregroundColor(GC.onLeather)
                        .padding(.horizontal, 6)
                        .frame(height: 36)
                }
                .buttonStyle(.plain)
            }
            .icon(kind)
            RulesView(kind: kind, players: players)
        }
        .background(FeltBackground())
        .preferredColorScheme(.light)
    }
}

struct RulesView: View {
    let kind: GameKind
    @State private var count: Int

    init(kind: GameKind, players: Int) {
        self.kind = kind
        _count = State(initialValue: min(max(players, kind.minPlayers), 8))
    }

    private var setup: Setup {
        return GameRules.setup(kind, players: count)
    }

    var body: some View {
        List {
            Section(header: Text("Players").foregroundColor(GC.onFeltDim)) {
                ChoiceChips(
                    items: (kind.minPlayers...8).map { String($0) },
                    selection: Binding<Int>(
                        get: { count - kind.minPlayers },
                        set: { count = $0 + kind.minPlayers }
                    ),
                    columns: 8
                )
            }
            .listRowBackground(GC.mantle)

            Section(header: Text("Setup for \(count) players").foregroundColor(GC.onFeltDim)) {
                LabeledContent("Decks", value: setup.decks)
                LabeledContent("Cards removed", value: setup.removed)
                LabeledContent("Hand", value: setup.hand)
                ForEach(setup.play, id: \.self) { line in
                    Text(line)
                        .font(.subheadline)
                }
            }
            .listRowBackground(GC.mantle)

            Section(header: Text("All player counts").foregroundColor(GC.onFeltDim)) {
                ForEach(kind.minPlayers...8, id: \.self) { n in
                    let s = GameRules.setup(kind, players: n)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(n) players")
                            .font(.subheadline.bold())
                        Text("Hand: \(s.hand)")
                            .font(.caption)
                        Text("Removed: \(s.removed)")
                            .font(.caption)
                            .foregroundColor(GC.dim)
                    }
                }
            }
            .listRowBackground(GC.mantle)

            ForEach(GameRules.overview(kind)) { section in
                Section(header: Text(section.title).foregroundColor(GC.onFeltDim)) {
                    ForEach(section.lines, id: \.self) { line in
                        Text(line)
                            .font(.subheadline)
                    }
                }
                .listRowBackground(GC.mantle)
            }
        }
        .scrollContentBackground(.hidden)
        .background(FeltBackground())
    }
}

struct StatsView: View {
    @EnvironmentObject var store: Store

    private var playerNames: [String] {
        return store.players.keys.sorted()
    }

    private var finished: [GameMatch] {
        return store.matches.filter { $0.finished }
    }

    var body: some View {
        VStack(spacing: 0) {
            GCHeader("Games won")
            statsList
        }
        .background(FeltBackground())
        .gcNavigation()
    }

    private var statsList: some View {
        List {
            Section(header: Text("Games won").foregroundColor(GC.onFeltDim)) {
                if playerNames.isEmpty {
                    Text("No finished games yet.")
                        .foregroundColor(GC.dim)
                }
                ForEach(playerNames, id: \.self) { name in
                    let perGame = store.players[name] ?? [:]
                    let won = perGame.values.reduce(0) { $0 + $1.won }
                    let played = perGame.values.reduce(0) { $0 + $1.played }
                    DisclosureGroup("\(name) · \(won) won of \(played)") {
                        ForEach(GameKind.allCases) { k in
                            if let t = perGame[k.rawValue] {
                                Text("\(k.title): \(t.won) won of \(t.played)")
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .listRowBackground(GC.mantle)

            Section(header: Text("Finished games").foregroundColor(GC.onFeltDim)) {
                if finished.isEmpty {
                    Text("None yet.")
                        .foregroundColor(GC.dim)
                }
                ForEach(finished) { m in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.kind.title)
                            .font(.subheadline.bold())
                        let w = m.winnerUnits.filter { $0 < m.units.count }.map { m.units[$0].name }
                        Text("Winner: " + w.joined(separator: " & "))
                            .font(.caption)
                        Text(m.names.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundColor(GC.dim)
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.map { finished[$0].id }
                    for id in ids {
                        store.delete(id)
                    }
                }
            }
            .listRowBackground(GC.mantle)
        }
        .scrollContentBackground(.hidden)
        .background(FeltBackground())
    }
}
