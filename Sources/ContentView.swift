import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: Store
    @State private var pendingDelete: UUID? = nil

    private var active: [GameMatch] {
        return store.matches.filter { !$0.finished }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    GCHeader("Discard", showBack: false) {
                        NavigationLink {
                            StatsView()
                        } label: {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundColor(GC.onLeather)
                                .frame(width: 36, height: 36)
                        }
                    }
                    ScrollView {
                        VStack(spacing: 18) {
                            LazyVGrid(
                                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                                spacing: 16
                            ) {
                                ForEach(GameKind.allCases) { kind in
                                    NavigationLink(value: kind) {
                                        VStack(spacing: 5) {
                                            GameTile(kind: kind, size: 80)
                                            Text(kind.title)
                                                .font(.subheadline.bold())
                                                .foregroundColor(GC.onFelt)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.7)
                                            Text(kind.playersText)
                                                .font(.caption2)
                                                .foregroundColor(GC.onFeltDim)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            if !active.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("IN PROGRESS")
                                        .font(.system(size: 13, weight: .heavy, design: .serif))
                                        .tracking(1.5)
                                        .foregroundColor(GC.dim)
                                    ForEach(active) { m in
                                        HStack(spacing: 6) {
                                            NavigationLink(value: m.id) {
                                                HStack(spacing: 10) {
                                                    GameTile(kind: m.kind, size: 40)
                                                    VStack(alignment: .leading, spacing: 1) {
                                                        Text(m.kind.title)
                                                            .font(.subheadline.bold())
                                                            .foregroundColor(GC.text)
                                                        Text(m.names.joined(separator: ", "))
                                                            .font(.caption)
                                                            .foregroundColor(GC.dim)
                                                            .lineLimit(1)
                                                    }
                                                    Spacer()
                                                }
                                            }
                                            .buttonStyle(.plain)
                                            Button {
                                                pendingDelete = m.id
                                            } label: {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 17, weight: .semibold))
                                                    .foregroundColor(GC.red)
                                                    .frame(width: 44, height: 44)
                                            }
                                            .buttonStyle(.plain)
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
                .background(FeltBackground())

                if let id = pendingDelete {
                    FlatMenuOverlay(
                        title: "Delete this game?",
                        actions: [
                            FlatAction(title: "Delete", destructive: true) {
                                store.delete(id)
                            }
                        ],
                        close: { pendingDelete = nil }
                    )
                }
            }
            .gcNavigation()
            .navigationDestination(for: GameKind.self) { kind in
                GameHomeView(kind: kind)
            }
            .navigationDestination(for: UUID.self) { id in
                MatchView(matchID: id)
            }
        }
        .preferredColorScheme(.light)
    }
}

struct GameHomeView: View {
    let kind: GameKind
    @EnvironmentObject var store: Store

    @State private var count = 4
    @State private var names: [String] = Array(repeating: "", count: 8)
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

    private var countChoices: [Int] {
        return Array(kind.minPlayers...8)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                GCHeader(kind.title) {
                    HeaderButton(symbol: "book") {
                        showRules = true
                    }
                }
                ScrollView {
                    VStack(spacing: 14) {
                        HStack(spacing: 14) {
                            GameTile(kind: kind, size: 56)
                            Text(kind.blurb)
                                .font(.subheadline)
                                .foregroundColor(GC.onFelt)
                            Spacer()
                        }

                        VStack(spacing: 10) {
                            HStack {
                                Text("How many players?")
                                    .font(.subheadline.bold())
                                    .foregroundColor(GC.text)
                                Spacer()
                            }
                            HStack(spacing: 6) {
                                ForEach(countChoices, id: \.self) { n in
                                    Text("\(n)")
                                        .font(.system(size: 18, weight: .heavy, design: .serif))
                                        .foregroundColor(GC.text)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(n == count ? GC.rosewater : GC.surface0)
                                        )
                                        .onTapGesture {
                                            count = n
                                        }
                                }
                            }

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(0..<count, id: \.self) { i in
                                    HStack(spacing: 8) {
                                        Text("\(i + 1)")
                                            .font(.system(size: 13, weight: .heavy, design: .serif))
                                            .foregroundColor(GC.base)
                                            .frame(width: 24, height: 24)
                                            .background(Circle().fill(seatColors[i]))
                                        TextField(
                                            "",
                                            text: $names[i],
                                            prompt: Text("Player \(i + 1)").foregroundColor(GC.overlay)
                                        )
                                        .foregroundColor(GC.text)
                                        .textInputAutocapitalization(.words)
                                        .autocorrectionDisabled()
                                    }
                                    .padding(6)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(GC.surface0))
                                }
                            }

                            Text(partnersText)
                                .font(.caption)
                                .foregroundColor(GC.dim)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .panel()

                        VStack(alignment: .leading, spacing: 8) {
                            targetControl
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .panel()

                        Button {
                            start()
                        } label: {
                            Label("Start game", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GlossButtonStyle())
                    }
                    .padding(16)
                }
            }
            .background(FeltBackground())
        }
        .gcNavigation()
        .fullScreenCover(isPresented: $showRules) {
            RulesSheet(kind: kind, players: count)
        }
        .navigationDestination(item: $started) { id in
            MatchView(matchID: id)
        }
    }

    @ViewBuilder
    private var targetControl: some View {
        switch kind {
        case .hearts:
            FlatStepper(label: "Game ends at \(target) points", value: $target, range: 50...200, step: 10)
        case .cribbage:
            ChoiceChips(
                items: ["121 (long)", "61 (short)"],
                selection: Binding<Int>(
                    get: { target == 61 ? 1 : 0 },
                    set: { target = $0 == 1 ? 61 : 121 }
                ),
                columns: 2
            )
        case .highLowJack:
            FlatStepper(label: "First to \(target)", value: $target, range: 5...21)
        case .spades:
            FlatStepper(label: "First to \(target)", value: $target, range: 100...1000, step: 50)
        case .euchre:
            FlatStepper(label: "First to \(target)", value: $target, range: 5...15)
        case .ohHell:
            Text("Plays \(GameRules.ohHellMax(count) * 2 - 1) rounds, highest score wins.")
                .font(.subheadline)
                .foregroundColor(GC.dim)
        case .war:
            Text("Last player holding cards wins.")
                .font(.subheadline)
                .foregroundColor(GC.dim)
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
        started = store.startMatch(kind: kind, names: resolved, dealer: 0, target: target)
    }
}
