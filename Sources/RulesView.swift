import SwiftUI

struct RulesView: View {
    let kind: GameKind
    @State private var count: Int

    init(kind: GameKind, players: Int) {
        self.kind = kind
        _count = State(initialValue: min(max(players, 2), 8))
    }

    private var setup: Setup {
        return GameRules.setup(kind, players: count)
    }

    var body: some View {
        List {
            Section("Players") {
                Picker("Number of players", selection: $count) {
                    ForEach(2...8, id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Setup for \(count) players") {
                LabeledContent("Decks", value: setup.decks)
                LabeledContent("Cards removed", value: setup.removed)
                LabeledContent("Hand", value: setup.hand)
                ForEach(setup.play, id: \.self) { line in
                    Text(line)
                        .font(.subheadline)
                }
            }

            Section("All player counts") {
                ForEach(2...8, id: \.self) { n in
                    let s = GameRules.setup(kind, players: n)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(n) players")
                            .font(.subheadline.bold())
                        Text("Hand: \(s.hand)")
                            .font(.caption)
                        Text("Removed: \(s.removed)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ForEach(GameRules.overview(kind)) { section in
                Section(section.title) {
                    ForEach(section.lines, id: \.self) { line in
                        Text(line)
                            .font(.subheadline)
                    }
                }
            }
        }
        .navigationTitle("\(kind.title) rules")
        .navigationBarTitleDisplayMode(.inline)
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
        List {
            Section("Lineups") {
                if store.lineups.isEmpty {
                    Text("Start a game to remember a lineup.")
                        .foregroundStyle(.secondary)
                }
                ForEach(store.lineups.sorted { $0.lastUsed > $1.lastUsed }) { l in
                    DisclosureGroup(l.names.joined(separator: ", ")) {
                        let anyPlayed = GameKind.allCases.contains { (l.played[$0.rawValue] ?? 0) > 0 }
                        if !anyPlayed {
                            Text("No finished games yet")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(GameKind.allCases) { k in
                            let played = l.played[k.rawValue] ?? 0
                            if played > 0 {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(k.title) · \(played) game\(played == 1 ? "" : "s")")
                                        .font(.subheadline.bold())
                                    let w = l.wins[k.rawValue] ?? [:]
                                    let line = l.names.map { "\($0) \(w[$0] ?? 0)" }.joined(separator: " · ")
                                    Text(line)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    let sorted = store.lineups.sorted { $0.lastUsed > $1.lastUsed }
                    let ids = offsets.map { sorted[$0].id }
                    store.lineups.removeAll { ids.contains($0.id) }
                    store.save()
                }
            }

            Section("Players") {
                if playerNames.isEmpty {
                    Text("No finished games yet.")
                        .foregroundStyle(.secondary)
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

            Section("Finished games") {
                if finished.isEmpty {
                    Text("None yet.")
                        .foregroundStyle(.secondary)
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
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.map { finished[$0].id }
                    for id in ids {
                        store.delete(id)
                    }
                }
            }
        }
        .navigationTitle("Games won")
    }
}
