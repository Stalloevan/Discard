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
                    VStack(spacing: 18) {
                        banner

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
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                        Text(kind.playersText)
                                            .font(.caption2)
                                            .foregroundColor(GC.dim)
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
                                    .foregroundColor(GC.gold)
                                ForEach(active) { m in
                                    NavigationLink(value: m.id) {
                                        HStack(spacing: 10) {
                                            GameTile(kind: m.kind, size: 40)
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
            .gcTitle("Discard")
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

    private var banner: some View {
        HStack(spacing: 14) {
            LogoTile(size: 66)
            VStack(alignment: .leading, spacing: 4) {
                Text("DISCARD")
                    .embossed(36)
                Text("Deal. Score. Win.")
                    .font(.subheadline)
                    .foregroundColor(GC.dim)
            }
            Spacer()
        }
        .padding(16)
        .background(LeatherBackground(corner: 20))
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

    private var countChoices: [Int] {
        return Array(kind.minPlayers...8)
    }

    var body: some View {
        ZStack {
            FeltBackground()
            ScrollView {
                VStack(spacing: 14) {
                    HStack(spacing: 14) {
                        GameTile(kind: kind, size: 62)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(kind.title.uppercased())
                                .embossed(26)
                            Text(kind.blurb)
                                .font(.caption)
                                .foregroundColor(GC.dim)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(LeatherBackground(corner: 18))

                    VStack(spacing: 10) {
                        HStack {
                            Text("How many players?")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Spacer()
                        }
                        HStack(spacing: 6) {
                            ForEach(countChoices, id: \.self) { n in
                                Text("\(n)")
                                    .font(.system(size: 18, weight: .heavy, design: .serif))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(n == count ? GC.button : Color.black.opacity(0.28))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(n == count ? GC.gold : Color.white.opacity(0.15), lineWidth: n == count ? 2 : 1)
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
                                        .foregroundColor(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Circle().fill(seatColors[i]))
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
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.28)))
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
                    .buttonStyle(GlossButtonStyle())
                }
                .padding(16)
            }
        }
        .gcTitle(kind.title)
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
