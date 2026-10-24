import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: Store

    private var active: [GameMatch] {
        return store.matches.filter { !$0.finished }
    }

    var body: some View {
        NavigationStack {
            List {
                if !active.isEmpty {
                    Section("In progress") {
                        ForEach(active) { m in
                            NavigationLink(value: m.id) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Label(m.kind.title, systemImage: m.kind.symbol)
                                        .font(.headline)
                                    Text(m.names.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { offsets in
                            let ids = offsets.map { active[$0].id }
                            for id in ids {
                                store.delete(id)
                            }
                        }
                    }
                }

                Section("Games") {
                    ForEach(GameKind.allCases) { kind in
                        NavigationLink(value: kind) {
                            HStack(spacing: 12) {
                                Image(systemName: kind.symbol)
                                    .font(.title2)
                                    .frame(width: 34)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(kind.title).font(.headline)
                                    Text(kind.blurb)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section {
                    NavigationLink {
                        StatsView()
                    } label: {
                        Label("Games won & lineups", systemImage: "trophy")
                    }
                }
            }
            .navigationTitle("Card Scores")
            .navigationDestination(for: GameKind.self) { kind in
                GameHomeView(kind: kind)
            }
            .navigationDestination(for: UUID.self) { id in
                MatchView(matchID: id)
            }
        }
    }
}

struct GameHomeView: View {
    let kind: GameKind
    @EnvironmentObject var store: Store

    @State private var count = 4
    @State private var names: [String] = Array(repeating: "", count: 8)
    @State private var dealer = 0
    @State private var target: Int
    @State private var started: UUID? = nil

    init(kind: GameKind) {
        self.kind = kind
        _target = State(initialValue: GameRules.setup(kind, players: 4).target)
    }

    private var setup: Setup {
        return GameRules.setup(kind, players: count)
    }

    private func display(_ i: Int) -> String {
        let t = names[i].trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Player \(i + 1)" : t
    }

    private var recent: [Lineup] {
        let sorted = store.lineups.sorted { $0.lastUsed > $1.lastUsed }
        return Array(sorted.prefix(6))
    }

    var body: some View {
        Form {
            Section("Players") {
                Picker("Number of players", selection: $count) {
                    ForEach(2...8, id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                }
                .pickerStyle(.segmented)

                ForEach(0..<count, id: \.self) { i in
                    HStack {
                        Circle()
                            .fill(seatColors[i])
                            .frame(width: 10, height: 10)
                        TextField("Player \(i + 1)", text: $names[i])
                            .textInputAutocapitalization(.words)
                    }
                }

                Picker("First dealer", selection: $dealer) {
                    ForEach(0..<count, id: \.self) { i in
                        Text(display(i)).tag(i)
                    }
                }
            }

            if !recent.isEmpty {
                Section("Recent lineups") {
                    ForEach(recent) { l in
                        Button {
                            count = l.names.count
                            for (i, n) in l.names.enumerated() where i < 8 {
                                names[i] = n
                            }
                            dealer = 0
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l.names.joined(separator: ", "))
                                    .foregroundStyle(.primary)
                                let played = l.played[kind.rawValue] ?? 0
                                Text(played == 0 ? "No \(kind.title) games yet" : "\(played) \(kind.title) games played")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            targetControl

            Section("Setup for \(count) players") {
                LabeledContent("Decks", value: setup.decks)
                LabeledContent("Cards removed", value: setup.removed)
                LabeledContent("Hand", value: setup.hand)
                if !setup.teams.isEmpty {
                    ForEach(0..<setup.teams.count, id: \.self) { t in
                        let who = setup.teams[t].map { display($0) }.joined(separator: " & ")
                        Text("Team \(t + 1): \(who)")
                            .font(.subheadline)
                    }
                }
                ForEach(setup.play, id: \.self) { line in
                    Text(line)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                NavigationLink {
                    RulesView(kind: kind, players: count)
                } label: {
                    Label("Rules for every player count", systemImage: "book")
                }
                Button {
                    start()
                } label: {
                    Label("Start game", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $started) { id in
            MatchView(matchID: id)
        }
        .onChange(of: count) { _, newValue in
            if dealer >= newValue { dealer = 0 }
        }
    }

    @ViewBuilder
    private var targetControl: some View {
        switch kind {
        case .hearts:
            Section("Game length") {
                Stepper("Game ends at \(target) points", value: $target, in: 50...200, step: 10)
            }
        case .cribbage:
            Section("Game length") {
                Picker("Play to", selection: $target) {
                    Text("121 (long)").tag(121)
                    Text("61 (short)").tag(61)
                }
                .pickerStyle(.segmented)
            }
        case .highLowJack:
            Section("Game length") {
                Stepper("First to \(target)", value: $target, in: 5...21)
            }
        case .spades:
            Section("Game length") {
                Stepper("First to \(target)", value: $target, in: 100...1000, step: 50)
            }
        case .euchre:
            Section("Game length") {
                Stepper("First to \(target)", value: $target, in: 5...15)
            }
        case .ohHell, .war:
            EmptyView()
        }
    }

    private func start() {
        var resolved: [String] = []
        for i in 0..<count {
            let base = display(i)
            var candidate = base
            var k = 2
            while resolved.contains(where: { $0.lowercased() == candidate.lowercased() }) {
                candidate = "\(base) \(k)"
                k += 1
            }
            resolved.append(candidate)
        }
        started = store.startMatch(kind: kind, names: resolved, dealer: dealer, target: target)
    }
}
