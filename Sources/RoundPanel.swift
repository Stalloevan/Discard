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

// MARK: Helpers

/// A binding that never lets a group of values add up to more than `cap`.
func cappedBinding(_ values: Binding<[Int]>, _ i: Int, cap: Int) -> Binding<Int> {
    return Binding<Int>(
        get: { i < values.wrappedValue.count ? values.wrappedValue[i] : 0 },
        set: { newValue in
            var arr = values.wrappedValue
            if i >= arr.count { return }
            var others = 0
            for (j, v) in arr.enumerated() where j != i {
                others += v
            }
            arr[i] = max(0, min(newValue, cap - others))
            values.wrappedValue = arr
        }
    )
}

func remainingRange(_ values: [Int], _ i: Int, cap: Int) -> ClosedRange<Int> {
    var others = 0
    for (j, v) in values.enumerated() where j != i {
        others += v
    }
    return 0...max(0, cap - others)
}

// MARK: Hearts

struct HeartsEntry: View {
    let match: GameMatch
    let onSave: (ScoreRound) -> Void
    @State private var values: [Int]

    init(match: GameMatch, onSave: @escaping (ScoreRound) -> Void) {
        self.match = match
        self.onSave = onSave
        _values = State(initialValue: Array(repeating: 0, count: match.units.count))
    }

    private var sum: Int {
        return values.reduce(0, +)
    }

    private var shooter: Int? {
        return values.firstIndex(of: 26)
    }

    var body: some View {
        let n = match.units.count
        VStack(spacing: 8) {
            HStack {
                Text("Points taken")
                    .font(.subheadline)
                    .foregroundColor(GC.dim)
                Spacer()
                Text(sum == 26 ? "26 / 26" : "\(26 - sum) left to enter")
                    .font(.subheadline.bold())
                    .foregroundColor(sum == 26 ? Color.green : GC.gold)
                    .monospacedDigit()
            }
            WheelRow(
                titles: match.units.map { $0.name },
                values: (0..<n).map { i in cappedBinding($values, i, cap: 26) },
                ranges: (0..<n).map { i in remainingRange(values, i, cap: 26) }
            )
            if let s = shooter {
                Text("\(match.units[s].name) took all 26 and shot the moon: everyone else scores 26.")
                    .font(.caption)
                    .foregroundColor(GC.gold)
            } else {
                Text("The hand always totals 26. One player taking all 26 shoots the moon.")
                    .font(.caption)
                    .foregroundColor(GC.dim)
            }
            Button("Save round") {
                var scores = values
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
            .frame(height: 200)
            Button("Save round") {
                save()
            }
            .buttonStyle(GlossButtonStyle())
            .disabled(tricksTotal != hand)
        }
    }

    private func page(_ i: Int) -> some View {
        let c = compute(i)
        let members = max(1, match.units[i].members.count)
        let nilMadeRange = 0...max(0, members - nilFailed[i])
        let nilFailedRange = 0...max(0, members - nilMade[i])
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
                WheelColumn(title: "Tricks", value: cappedBinding($tricks, i, cap: hand), range: remainingRange(tricks, i, cap: hand))
                WheelColumn(title: "Nil made", value: $nilMade[i], range: nilMadeRange)
                WheelColumn(title: "Nil failed", value: $nilFailed[i], range: nilFailedRange)
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
        let n = match.units.count
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
                    values: (0..<n).map { i in $bid[i] },
                    range: 0...hand
                )
                Text("Bids add to \(bidSum)" + (bidSum == hand ? ". The total can't equal \(hand), so change a bid." : ""))
                    .font(.caption)
                    .foregroundColor(bidSum == hand ? Color.red : GC.dim)
            } else {
                WheelRow(
                    titles: match.units.map { $0.name },
                    values: (0..<n).map { i in cappedBinding($took, i, cap: hand) },
                    ranges: (0..<n).map { i in remainingRange(took, i, cap: hand) }
                )
                Text("Tricks entered: \(tookSum) of \(hand)")
                    .font(.caption)
                    .foregroundColor(tookSum == hand ? Color.green : GC.gold)
            }
            Button("Save round") {
                var scores: [Int] = []
                for i in 0..<n {
                    scores.append(bid[i] == took[i] ? 10 + bid[i] : 0)
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
        "Made +1",
        "March +2",
        "Alone +4",
        "Euchre +2"
    ]

    init(match: GameMatch, onSave: @escaping (ScoreRound) -> Void) {
        self.match = match
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                StampDrum(
                    title: "Called trump",
                    labels: match.units.map { $0.name },
                    selection: $maker,
                    width: nil,
                    height: 112
                )
                StampDrum(
                    title: "Result (euchre: other side scores)",
                    labels: outcomes,
                    selection: $outcome,
                    width: nil,
                    height: 112
                )
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
        let n = match.units.count
        VStack(spacing: 8) {
            Picker("Entry", selection: $page) {
                Text("Bid").tag(0)
                Text("Points won").tag(1)
            }
            .pickerStyle(.segmented)
            if page == 0 {
                HStack(alignment: .top, spacing: 10) {
                    StampDrum(
                        title: "Bidder",
                        labels: match.units.map { $0.name },
                        selection: $bidder,
                        width: nil,
                        height: 112
                    )
                    StampWheel(title: "Bid", value: $bid, range: 1...4, width: nil, height: 112)
                }
            } else {
                WheelRow(
                    titles: match.units.map { $0.name },
                    values: (0..<n).map { i in cappedBinding($pts, i, cap: 4) },
                    ranges: (0..<n).map { i in remainingRange(pts, i, cap: 4) }
                )
                Text("High, Low, Jack, Game: \(sum) of 4")
                    .font(.caption)
                    .foregroundColor(GC.dim)
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
        }
    }
}
