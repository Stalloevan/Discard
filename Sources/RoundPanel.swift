import SwiftUI

/// Inline round entry shown under the scoreboard (no sheet, no scrolling).
struct RoundPanel: View {
    let matchID: UUID
    @EnvironmentObject var store: Store

    private var match: GameMatch? {
        return store.matches.first { $0.id == matchID }
    }

    var body: some View {
        if let m = match {
            VStack(alignment: .leading, spacing: 8) {
                header(m)
                if m.finished {
                    Text("Game over.")
                        .foregroundColor(GC.dim)
                } else if m.kind == .ohHell && m.currentHand == nil {
                    Text("All rounds played.")
                        .foregroundColor(GC.dim)
                } else {
                    entry(m)
                        .id(m.rounds.count)
                }
            }
        }
    }

    private func header(_ m: GameMatch) -> some View {
        var title = "Round \(m.rounds.count + 1)"
        var sub = ""
        if m.kind == .ohHell {
            title = "Round \(m.rounds.count + 1) of \(m.ohHellHands.count)"
            if let h = m.currentHand { sub = "Deal \(h) each" }
        } else {
            sub = "Deal \(GameRules.handSize(m.kind, m.names.count)) each"
        }
        return HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Text(sub)
                .font(.subheadline)
                .foregroundColor(GC.dim)
        }
    }

    private func save(_ r: ScoreRound) {
        store.addRound(matchID, r)
    }

    @ViewBuilder
    private func entry(_ m: GameMatch) -> some View {
        switch m.kind {
        case .hearts:
            HeartsEntry(match: m, onSave: save)
        case .spades:
            SpadesEntry(match: m, onSave: save)
        case .ohHell:
            OhHellEntry(match: m, onSave: save)
        case .euchre:
            EuchreEntry(match: m, onSave: save)
        case .highLowJack:
            HLJEntry(match: m, onSave: save)
        case .cribbage, .war:
            EmptyView()
        }
    }
}

// MARK: Hearts

struct HeartsEntry: View {
    let match: GameMatch
    let onSave: (ScoreRound) -> Void
    @State private var values: [Int]
    @State private var moon: Int = -1

    init(match: GameMatch, onSave: @escaping (ScoreRound) -> Void) {
        self.match = match
        self.onSave = onSave
        _values = State(initialValue: Array(repeating: 0, count: match.units.count))
    }

    private var sum: Int {
        return values.reduce(0, +)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Points taken")
                    .font(.subheadline)
                    .foregroundColor(GC.dim)
                Spacer()
                Text("\(sum) / 26")
                    .font(.subheadline.bold())
                    .foregroundColor(sum == 26 || moon >= 0 ? Color.green : GC.gold)
                    .monospacedDigit()
            }
            WheelRow(
                titles: match.units.map { $0.name },
                values: (0..<match.units.count).map { i in $values[i] },
                range: 0...26
            )
            HStack {
                Text("Shot the moon")
                    .font(.subheadline)
                    .foregroundColor(GC.dim)
                Spacer()
                Picker("Shooter", selection: $moon) {
                    Text("No one").tag(-1)
                    ForEach(0..<match.units.count, id: \.self) { i in
                        Text(match.units[i].name).tag(i)
                    }
                }
                .pickerStyle(.menu)
                .tint(GC.gold)
            }
            Button("Save round") {
                let n = match.units.count
                var scores = values
                var detail = ""
                if moon >= 0 {
                    scores = []
                    for i in 0..<n {
                        scores.append(i == moon ? 0 : 26)
                    }
                    detail = "\(match.units[moon].name) shot the moon"
                }
                var r = ScoreRound(scores: scores)
                r.detail = detail
                onSave(r)
            }
            .buttonStyle(GlossButtonStyle())
            .disabled(!(moon >= 0 || sum == 26))
        }
    }
}

// MARK: Spades

struct SpadesEntry: View {
    let match: GameMatch
    let onSave: (ScoreRound) -> Void
    @State private var bid: [Int]
    @State private var tricks: [Int]
    @State private var nilMade: [Int]
    @State private var nilFailed: [Int]

    init(match: GameMatch, onSave: @escaping (ScoreRound) -> Void) {
        self.match = match
        self.onSave = onSave
        let n = match.units.count
        _bid = State(initialValue: Array(repeating: 0, count: n))
        _tricks = State(initialValue: Array(repeating: 0, count: n))
        _nilMade = State(initialValue: Array(repeating: 0, count: n))
        _nilFailed = State(initialValue: Array(repeating: 0, count: n))
    }

    private var hand: Int {
        return GameRules.handSize(.spades, match.names.count)
    }

    private var tricksTotal: Int {
        return tricks.reduce(0, +)
    }

    private func compute(_ i: Int) -> (pts: Int, bags: Int) {
        let b = bid[i]
        let t = tricks[i]
        var pts = 0
        var bags = 0
        let nilUsed = nilMade[i] + nilFailed[i] > 0
        if b > 0 {
            if t >= b {
                pts += 10 * b + (t - b)
                bags = t - b
            } else {
                pts -= 10 * b
            }
        } else if !nilUsed {
            pts += t
            bags = t
        }
        pts += 100 * nilMade[i]
        pts -= 100 * nilFailed[i]
        return (pts, bags)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(match.units.count > 1 ? "Swipe for each side" : "")
                    .font(.caption)
                    .foregroundColor(GC.dim)
                Spacer()
                Text("Tricks \(tricksTotal) / \(hand)")
                    .font(.subheadline.bold())
                    .foregroundColor(tricksTotal == hand ? Color.green : GC.gold)
                    .monospacedDigit()
            }
            TabView {
                ForEach(0..<match.units.count, id: \.self) { i in
                    page(i)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .never))
            .frame(height: 190)
            Button("Save round") {
                save()
            }
            .buttonStyle(GlossButtonStyle())
        }
    }

    private func page(_ i: Int) -> some View {
        let c = compute(i)
        let nilMax = max(1, match.units[i].members.count)
        return VStack(spacing: 2) {
            HStack {
                Text(match.units[i].name)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
                Text("\(signed(c.pts)) · bags +\(c.bags)")
                    .font(.caption)
                    .foregroundColor(GC.dim)
            }
            HStack(spacing: 6) {
                WheelColumn(title: "Bid", value: $bid[i], range: 0...hand)
                WheelColumn(title: "Tricks", value: $tricks[i], range: 0...hand)
                WheelColumn(title: "Nil made", value: $nilMade[i], range: 0...nilMax)
                WheelColumn(title: "Nil failed", value: $nilFailed[i], range: 0...nilMax)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.bottom, 22)
    }

    private func save() {
        var scores: [Int] = []
        var extra: [Int] = []
        var detail: [String] = []
        for i in 0..<match.units.count {
            let c = compute(i)
            let prior = match.bags(i)
            var b = prior + c.bags
            var penalty = 0
            while b >= 10 {
                b -= 10
                penalty -= 100
            }
            scores.append(c.pts + penalty)
            extra.append(b - prior)
            var d = "\(match.units[i].name): bid \(bid[i]), took \(tricks[i])"
            if penalty < 0 { d += ", bag penalty" }
            detail.append(d)
        }
        var r = ScoreRound(scores: scores)
        r.extra = extra
        r.detail = detail.joined(separator: " · ")
        onSave(r)
    }
}

// MARK: Oh Hell

struct OhHellEntry: View {
    let match: GameMatch
    let onSave: (ScoreRound) -> Void
    @State private var bid: [Int]
    @State private var took: [Int]
    @State private var page = 0

    init(match: GameMatch, onSave: @escaping (ScoreRound) -> Void) {
        self.match = match
        self.onSave = onSave
        let n = match.units.count
        _bid = State(initialValue: Array(repeating: 0, count: n))
        _took = State(initialValue: Array(repeating: 0, count: n))
    }

    private var hand: Int {
        return match.currentHand ?? 1
    }

    var body: some View {
        let bidSum = bid.reduce(0, +)
        let tookSum = took.reduce(0, +)
        VStack(spacing: 8) {
            Picker("Entry", selection: $page) {
                Text("Bids").tag(0)
                Text("Tricks won").tag(1)
            }
            .pickerStyle(.segmented)
            if page == 0 {
                WheelRow(
                    titles: match.units.map { $0.name },
                    values: (0..<match.units.count).map { i in $bid[i] },
                    range: 0...hand
                )
                Text("Bids add to \(bidSum)" + (bidSum == hand ? " (dealer can't make it equal \(hand))" : ""))
                    .font(.caption)
                    .foregroundColor(bidSum == hand ? GC.gold : GC.dim)
            } else {
                WheelRow(
                    titles: match.units.map { $0.name },
                    values: (0..<match.units.count).map { i in $took[i] },
                    range: 0...hand
                )
                Text("Tricks entered: \(tookSum) of \(hand)")
                    .font(.caption)
                    .foregroundColor(tookSum == hand ? Color.green : GC.gold)
            }
            Button("Save round") {
                var scores: [Int] = []
                for i in 0..<match.units.count {
                    scores.append(bid[i] == took[i] ? 10 + bid[i] : 0)
                }
                var r = ScoreRound(scores: scores)
                r.detail = "\(hand) cards"
                onSave(r)
            }
            .buttonStyle(GlossButtonStyle())
        }
    }
}

// MARK: Euchre

struct EuchreEntry: View {
    let match: GameMatch
    let onSave: (ScoreRound) -> Void
    @State private var maker = 0
    @State private var outcome = 0

    private let outcomes: [String] = [
        "Made it +1",
        "March +2",
        "Alone +4",
        "Euchred: they +2"
    ]

    init(match: GameMatch, onSave: @escaping (ScoreRound) -> Void) {
        self.match = match
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(spacing: 2) {
                    Text("Called trump")
                        .font(.caption2)
                        .foregroundColor(GC.dim)
                    Picker("Makers", selection: $maker) {
                        ForEach(0..<match.units.count, id: \.self) { i in
                            Text(match.units[i].name).tag(i)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 124)
                    .environment(\.colorScheme, .dark)
                }
                VStack(spacing: 2) {
                    Text("Result")
                        .font(.caption2)
                        .foregroundColor(GC.dim)
                    Picker("Result", selection: $outcome) {
                        ForEach(0..<outcomes.count, id: \.self) { i in
                            Text(outcomes[i]).tag(i)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 124)
                    .environment(\.colorScheme, .dark)
                }
            }
            Button("Save round") {
                var scores: [Int] = Array(repeating: 0, count: match.units.count)
                if outcome == 3 {
                    for i in 0..<scores.count where i != maker {
                        scores[i] = 2
                    }
                } else {
                    let pts = [1, 2, 4][outcome]
                    scores[maker] = pts
                }
                var r = ScoreRound(scores: scores)
                r.detail = "\(match.units[maker].name) called: \(outcomes[outcome])"
                onSave(r)
            }
            .buttonStyle(GlossButtonStyle())
        }
    }
}

// MARK: High-Low-Jack

struct HLJEntry: View {
    let match: GameMatch
    let onSave: (ScoreRound) -> Void
    @State private var bidder = 0
    @State private var bid = 1
    @State private var pts: [Int]
    @State private var page = 0

    init(match: GameMatch, onSave: @escaping (ScoreRound) -> Void) {
        self.match = match
        self.onSave = onSave
        _pts = State(initialValue: Array(repeating: 0, count: match.units.count))
    }

    private var sum: Int {
        return pts.reduce(0, +)
    }

    var body: some View {
        VStack(spacing: 8) {
            Picker("Entry", selection: $page) {
                Text("Bid").tag(0)
                Text("Points won").tag(1)
            }
            .pickerStyle(.segmented)
            if page == 0 {
                HStack(alignment: .top, spacing: 8) {
                    VStack(spacing: 2) {
                        Text("Bidder")
                            .font(.caption2)
                            .foregroundColor(GC.dim)
                        Picker("Bidder", selection: $bidder) {
                            ForEach(0..<match.units.count, id: \.self) { i in
                                Text(match.units[i].name).tag(i)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 124)
                        .environment(\.colorScheme, .dark)
                    }
                    VStack(spacing: 2) {
                        Text("Bid")
                            .font(.caption2)
                            .foregroundColor(GC.dim)
                        Picker("Bid", selection: $bid) {
                            ForEach(1...4, id: \.self) { n in
                                Text("\(n)").tag(n)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 124)
                        .environment(\.colorScheme, .dark)
                    }
                }
            } else {
                WheelRow(
                    titles: match.units.map { $0.name },
                    values: (0..<match.units.count).map { i in $pts[i] },
                    range: 0...4
                )
                Text("High, Low, Jack, Game: \(sum) of 4")
                    .font(.caption)
                    .foregroundColor(sum <= 4 ? GC.dim : Color.red)
            }
            Button("Save round") {
                var scores = pts
                var detail = "\(match.units[bidder].name) bid \(bid) and made it"
                if pts[bidder] < bid {
                    scores[bidder] = -bid
                    detail = "\(match.units[bidder].name) bid \(bid) and was set"
                }
                var r = ScoreRound(scores: scores)
                r.detail = detail
                onSave(r)
            }
            .buttonStyle(GlossButtonStyle())
            .disabled(sum > 4)
        }
    }
}
