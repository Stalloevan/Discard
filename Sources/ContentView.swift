import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: Store

    private var active: [GameMatch] {
        return store.matches.filter { !$0.finished }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FeltBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                            spacing: 14
                        ) {
                            ForEach(GameKind.allCases) { kind in
                                NavigationLink(value: kind) {
                                    VStack(spacing: 6) {
                                        Bubble(color: kind.color, size: 84) {
                                            Image(systemName: kind.symbol)
                                                .font(.system(size: 32))
                                                .foregroundColor(.white)
                                                .shadow(color: Color.black.opacity(0.4), radius: 1, x: 0, y: 1)
                                        }
                                        Text(kind.title)
                                            .font(.subheadline.bold())
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !active.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("In progress")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                ForEach(active) { m in
                                    NavigationLink(value: m.id) {
                                        HStack(spacing: 10) {
                                            Bubble(color: m.kind.color, size: 38) {
                                                Image(systemName: m.kind.symbol)
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.white)
                                            }
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(m.kind.title)
                                                    .font(.subheadline.bold())
                                                    .foregroundColor(.white)
                                                Text(m.names.joined(separator: ", "))
                                                    .font(.caption)
                                                    .foregroundColor(GC.dim)
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(GC.dim)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            store.delete(m.id)
                                        } label: {
                                            Label("Delete game", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .panel()
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Card Scores")
            .navigationBarTitleDisplayMode(.inline)
            .gcNavigation()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        StatsView()
                    } label: {
                        Image(systemName: "trophy.fill")
                    }
                }
            }
            .navigationDestination(for: GameKind.self) { kind in
                GameHomeView(kind: kind)
            }
            .navigationDestination(for: UUID.self) { id in
                MatchView(matchID: id)
            }
        }
        .preferredColorScheme(.dark)
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
    @State private var showRules = false

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

    private var partnersText: String {
        if setup.teams.isEmpty { return "Everyone plays for themselves." }
        var parts: [String] = []
        for team in setup.teams {
            parts.append(team.map { display($0) }.joined(separator: " & "))
        }
        return "Teams: " + parts.joined(separator: "  vs  ")
    }

    var body: some View {
        ZStack {
            FeltBackground()
            ScrollView {
                VStack(spacing: 12) {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Players")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        Picker("Number of players", selection: $count) {
                            ForEach(kind.minPlayers...8, id: \.self) { n in
                                Text("\(n)").tag(n)
                            }
                        }
                        .pickerStyle(.segmented)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(0..<count, id: \.self) { i in
                                HStack(spacing: 8) {
                                    Bubble(color: seatColors[i], size: 26) {
                                        Text("\(i + 1)")
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                    }
                                    TextField(
                                        "",
                                        text: $names[i],
                                        prompt: Text("Player \(i + 1)").foregroundColor(Color.white.opacity(0.45))
                                    )
                                    .foregroundColor(.white)
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled()
                                }
                                .padding(6)
                                .background(Capsule().fill(Color.black.opacity(0.3)))
                            }
                        }

                        Text(partnersText)
                            .font(.caption)
                            .foregroundColor(GC.dim)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .panel()

                    VStack(spacing: 8) {
                        HStack {
                            Text("First dealer")
                                .foregroundColor(.white)
                            Spacer()
                            Picker("First dealer", selection: $dealer) {
                                ForEach(0..<count, id: \.self) { i in
                                    Text(display(i)).tag(i)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(GC.gold)
                        }
                        targetControl
                    }
                    .panel()

                    Button {
                        start()
                    } label: {
                        Label("Start game", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GlossButtonStyle(tint: Color.green))
                }
                .padding(16)
            }
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .gcNavigation()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showRules = true
                } label: {
                    Image(systemName: "book")
                }
            }
        }
        .sheet(isPresented: $showRules) {
            RulesSheet(kind: kind, players: count)
        }
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
            Stepper(value: $target, in: 50...200, step: 10) {
                Text("Game ends at \(target) points").foregroundColor(.white)
            }
        case .cribbage:
            Picker("Play to", selection: $target) {
                Text("121 (long)").tag(121)
                Text("61 (short)").tag(61)
            }
            .pickerStyle(.segmented)
        case .highLowJack:
            Stepper(value: $target, in: 5...21) {
                Text("First to \(target)").foregroundColor(.white)
            }
        case .spades:
            Stepper(value: $target, in: 100...1000, step: 50) {
                Text("First to \(target)").foregroundColor(.white)
            }
        case .euchre:
            Stepper(value: $target, in: 5...15) {
                Text("First to \(target)").foregroundColor(.white)
            }
        case .ohHell:
            Text("Plays \(GameRules.ohHellMax(count) * 2 - 1) rounds, highest score wins.")
                .font(.subheadline)
                .foregroundColor(GC.dim)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .war:
            Text("Last player holding cards wins.")
                .font(.subheadline)
                .foregroundColor(GC.dim)
                .frame(maxWidth: .infinity, alignment: .leading)
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
