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
    @State private var values: [[Int]]

    init(match: GameMatch, onSave: @escaping (ScoreRound) -> Void) {
        self.match = match
        self.onSave = onSave
        _values = State(initialValue: [Array(repeating: 0, count: match.units.count)])
    }

    private var sum: Int {
        return values[0].reduce(0, +)
    }

    private var shooter: Int? {
        return values[0].firstIndex(of: 26)
    }

    var body: some View {
        let n = match.units.count
        VStack(spacing: 8) {
            HStack {
                Text("Points taken this hand")
                    .font(.subheadline)
                    .foregroundColor(GC.dim)
                Spacer()
                Text(sum == 26 ? "26 / 26" : "\(26 - sum) left to enter")
                    .font(.subheadline.bold())
                    .foregroundColor(sum == 26 ? Color.green : GC.gold)
                    .monospacedDigit()
            }
            DrumPad(
                titles: match.units.map { $0.name },
                fieldNames: ["Points"],
                values: $values,
                ranges: { _, u in remainingRange(values[0], u, cap: 26) },
                summary: { u in "\(values[0][u])" },
                info: { _ in
                    if let s = shooter {
                        return "\(match.units[s].name) took all 26: shot the moon, everyone else scores 26."
                    }
                    return "One player taking all 26 shoots the moon."
                }
            )
            Button("Save round") {
                var scores = values[0]
                var detail = ""
                if let s = shooter {
                    scores = []
                    for i in 0..<n {
                        scores.append(i == s ? 0 : 26)
                    }
                    detail = "\(match.units[s].name) shot the moon"
                }
                var r = ScoreRound(scores: scores)
                r.detail = detail
                onSave(r)
            }
            .buttonStyle(GlossButtonStyle())
            .disabled(sum != 26)
        }
    }
}

// MARK: Spades

struct SpadesEntry: View {
    let match: GameMatch
    let onSave: (ScoreRound) -> Void
    @State private var values: [[Int]]   // bid, tricks, nil made, nil failed

    init(match: GameMatch, onSave: @escaping (ScoreRound) -> Void) {
        self.match = match
        self.onSave = onSave
        let n = match.units.count
        _values = State(initialValue: Array(repeating: Array(repeating: 0, count: n), count: 4))
    }

    private var hand: Int {
        return GameRules.handSize(.spades, match.names.count)
    }

    private var tricksTotal: Int {
        return values[1].reduce(0, +)
    }

    private func compute(_ i: Int) -> (pts: Int, bags: Int) {
        let b = values[0][i]
        let t = values[1][i]
        let nm = values[2][i]
        let nf = values[3][i]
        var pts = 0
        var bags = 0
        let nilUsed = nm + nf > 0
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
        pts += 100 * nm
        pts -= 100 * nf
        return (pts, bags)
    }

    private func range(_ f: Int, _ u: Int) -> ClosedRange<Int> {
        let members = max(1, match.units[u].members.count)
        switch f {
        case 0: return 0...hand
        case 1: return remainingRange(values[1], u, cap: hand)
        case 2: return 0...max(0, members - values[3][u])
        default: return 0...max(0, members - values[2][u])
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Bid, tricks taken, nils")
                    .font(.subheadline)
                    .foregroundColor(GC.dim)
                Spacer()
                Text("Tricks \(tricksTotal) / \(hand)")
                    .font(.subheadline.bold())
                    .foregroundColor(tricksTotal == hand ? Color.green : GC.gold)
                    .monospacedDigit()
            }
            DrumPad(
                titles: match.units.map { $0.name },
                fieldNames: ["Bid", "Tricks", "Nil made", "Nil failed"],
                values: $values,
                ranges: { f, u in range(f, u) },
                summary: { u in "\(values[0][u]) / \(values[1][u])" },
                info: { u in
                    let c = compute(u)
                    return "\(match.units[u].name): hand \(signed(c.pts)), new bags +\(c.bags)"
                }
            )
            Button("Save round") {
                save()
            }
            .buttonStyle(GlossButtonStyle())
            .disabled(tricksTotal != hand)
        }
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
            var d = "\(match.units[i].name): bid \(values[0][i]), took \(values[1][i])"
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
    @State private var values: [[Int]]   // bid, tricks won

    init(match: GameMatch, onSave: @escaping (ScoreRound) -> Void) {
        self.match = match
        self.onSave = onSave
        let n = match.units.count
        _values = State(initialValue: Array(repeating: Array(repeating: 0, count: n), count: 2))
    }

    private var hand: Int {
        return match.currentHand ?? 1
    }

    var body: some View {
        let n = match.units.count
        let bidSum = values[0].reduce(0, +)
        let tookSum = values[1].reduce(0, +)
        VStack(spacing: 8) {
            HStack {
                Text("Bids \(bidSum)")
                    .font(.subheadline.bold())
                    .foregroundColor(bidSum == hand ? Color.red : GC.dim)
                    .monospacedDigit()
                Spacer()
                Text("Tricks \(tookSum) / \(hand)")
                    .font(.subheadline.bold())
                    .foregroundColor(tookSum == hand ? Color.green : GC.gold)
                    .monospacedDigit()
            }
            DrumPad(
                titles: match.units.map { $0.name },
                fieldNames: ["Bid", "Tricks won"],
                values: $values,
                ranges: { f, u in
                    if f == 0 { return 0...hand }
                    return remainingRange(values[1], u, cap: hand)
                },
                summary: { u in "\(values[0][u]) / \(values[1][u])" },
                info: { _ in
                    if bidSum == hand {
                        return "Bids can't add up to \(hand). Change one."
                    }
                    return "Bids / tricks won"
                }
            )
            Button("Save round") {
                var scores: [Int] = []
                for i in 0..<n {
                    scores.append(values[0][i] == values[1][i] ? 10 + values[0][i] : 0)
                }
                var r = ScoreRound(scores: scores)
                r.detail = "\(hand) cards"
                onSave(r)
            }
            .buttonStyle(GlossButtonStyle())
            .disabled(tookSum != hand || bidSum == hand)
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
        "Alone march +4",
        "Euchred: others +2"
    ]

    init(match: GameMatch, onSave: @escaping (ScoreRound) -> Void) {
        self.match = match
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Who called trump?")
                .font(.subheadline)
                .foregroundColor(GC.dim)
            ChoiceChips(items: match.units.map { $0.name }, selection: $maker, columns: 4)
            Text("Result")
                .font(.subheadline)
                .foregroundColor(GC.dim)
            ChoiceChips(items: outcomes, selection: $outcome, columns: 2)
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
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: High-Low-Jack

struct HLJEntry: View {
    let match: GameMatch
    let onSave: (ScoreRound) -> Void
    @State private var bidder = 0
    @State private var bid = 0          // index into 1...4
    @State private var values: [[Int]]
    @State private var page = 0

    init(match: GameMatch, onSave: @escaping (ScoreRound) -> Void) {
        self.match = match
        self.onSave = onSave
        _values = State(initialValue: [Array(repeating: 0, count: match.units.count)])
    }

    private var sum: Int {
        return values[0].reduce(0, +)
    }

    var body: some View {
        VStack(spacing: 8) {
            Picker("Entry", selection: $page) {
                Text("Bid").tag(0)
                Text("Points won").tag(1)
            }
            .pickerStyle(.segmented)
            if page == 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Who bid?")
                        .font(.subheadline)
                        .foregroundColor(GC.dim)
                    ChoiceChips(items: match.units.map { $0.name }, selection: $bidder, columns: 4)
                    Text("Bid")
                        .font(.subheadline)
                        .foregroundColor(GC.dim)
                    ChoiceChips(items: ["1", "2", "3", "4"], selection: $bid, columns: 4)
                }
            } else {
                HStack {
                    Text("High, Low, Jack, Game")
                        .font(.subheadline)
                        .foregroundColor(GC.dim)
                    Spacer()
                    Text("\(sum) of 4")
                        .font(.subheadline.bold())
                        .foregroundColor(GC.gold)
                        .monospacedDigit()
                }
                DrumPad(
                    titles: match.units.map { $0.name },
                    fieldNames: ["Points"],
                    values: $values,
                    ranges: { _, u in remainingRange(values[0], u, cap: 4) },
                    summary: { u in "\(values[0][u])" }
                )
            }
            Button("Save round") {
                var scores = values[0]
                let amount = bid + 1
                var detail = "\(match.units[bidder].name) bid \(amount) and made it"
                if scores[bidder] < amount {
                    scores[bidder] = -amount
                    detail = "\(match.units[bidder].name) bid \(amount) and was set"
                }
                var r = ScoreRound(scores: scores)
                r.detail = detail
                onSave(r)
            }
            .buttonStyle(GlossButtonStyle())
        }
    }
}
