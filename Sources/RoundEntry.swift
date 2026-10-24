import SwiftUI

struct RoundEntryView: View {
    let matchID: UUID
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let m = store.matches.first(where: { $0.id == matchID }) {
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
                        Text("This game doesn't use rounds.")
                    }
                } else {
                    Text("Game not found.")
                }
            }
            .navigationTitle("Add round")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func save(_ r: ScoreRound) {
        store.addRound(matchID, r)
        dismiss()
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

    private var canSave: Bool {
        return moon >= 0 || sum == 26
    }

    var body: some View {
        Form {
            Section("Points taken this hand") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<match.units.count, id: \.self) { i in
                            WheelColumn(title: match.units[i].name, value: $values[i], range: 0...26)
                        }
                    }
                }
                HStack {
                    Text("Total")
                    Spacer()
                    Text("\(sum) / 26")
                        .foregroundStyle(sum == 26 ? Color.green : Color.orange)
                        .monospacedDigit()
                }
            }
            Section("Shot the moon?") {
                Picker("Shooter", selection: $moon) {
                    Text("No").tag(-1)
                    ForEach(0..<match.units.count, id: \.self) { i in
                        Text(match.units[i].name).tag(i)
                    }
                }
                Text("The shooter scores 0 and everyone else scores 26.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
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
                .disabled(!canSave)
            }
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
        Form {
            ForEach(0..<match.units.count, id: \.self) { i in
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            WheelColumn(title: "Bid", value: $bid[i], range: 0...hand)
                            WheelColumn(title: "Tricks", value: $tricks[i], range: 0...hand)
                            WheelColumn(title: "Nil made", value: $nilMade[i], range: 0...max(1, match.units[i].members.count))
                            WheelColumn(title: "Nil failed", value: $nilFailed[i], range: 0...max(1, match.units[i].members.count))
                        }
                    }
                    let c = compute(i)
                    Text("Hand score \(signed(c.pts)) · new bags \(c.bags)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text(match.units[i].name)
                }
            }
            Section {
                Text("Tricks entered: \(tricksTotal) of \(hand)")
                    .foregroundStyle(tricksTotal == hand ? Color.green : Color.orange)
                Button("Save round") {
                    save()
                }
            }
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
        Form {
            Section("Round \(match.rounds.count + 1): \(hand) cards each") {
                Text("Bids")
                    .font(.subheadline.bold())
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<match.units.count, id: \.self) { i in
                            WheelColumn(title: match.units[i].name, value: $bid[i], range: 0...hand)
                        }
                    }
                }
                let bidSum = bid.reduce(0, +)
                Text("Bids add to \(bidSum)" + (bidSum == hand ? " (not allowed for the dealer's bid)" : ""))
                    .font(.caption)
                    .foregroundStyle(bidSum == hand ? Color.orange : Color.secondary)
            }
            Section("Tricks taken") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<match.units.count, id: \.self) { i in
                            WheelColumn(title: match.units[i].name, value: $took[i], range: 0...hand)
                        }
                    }
                }
                let tookSum = took.reduce(0, +)
                Text("Tricks entered: \(tookSum) of \(hand)")
                    .font(.caption)
                    .foregroundStyle(tookSum == hand ? Color.green : Color.orange)
            }
            Section {
                Button("Save round") {
                    var scores: [Int] = []
                    for i in 0..<match.units.count {
                        scores.append(bid[i] == took[i] ? 10 + bid[i] : 0)
                    }
                    var r = ScoreRound(scores: scores)
                    r.detail = "\(hand) cards"
                    onSave(r)
                }
            }
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
        "Makers made it (+1)",
        "March: all tricks (+2)",
        "Alone and march (+4)",
        "Euchred: defenders +2"
    ]

    init(match: GameMatch, onSave: @escaping (ScoreRound) -> Void) {
        self.match = match
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Who called trump?") {
                Picker("Makers", selection: $maker) {
                    ForEach(0..<match.units.count, id: \.self) { i in
                        Text(match.units[i].name).tag(i)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 110)
            }
            Section("Result") {
                Picker("Result", selection: $outcome) {
                    ForEach(0..<outcomes.count, id: \.self) { i in
                        Text(outcomes[i]).tag(i)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 110)
            }
            Section {
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
            }
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

    init(match: GameMatch, onSave: @escaping (ScoreRound) -> Void) {
        self.match = match
        self.onSave = onSave
        _pts = State(initialValue: Array(repeating: 0, count: match.units.count))
    }

    private var sum: Int {
        return pts.reduce(0, +)
    }

    var body: some View {
        Form {
            Section("Bid") {
                Picker("Bidder", selection: $bidder) {
                    ForEach(0..<match.units.count, id: \.self) { i in
                        Text(match.units[i].name).tag(i)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 100)
                HStack {
                    Text("Bid amount")
                    Spacer()
                    Picker("Bid amount", selection: $bid) {
                        ForEach(1...4, id: \.self) { n in
                            Text("\(n)").tag(n)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
            }
            Section("Points won (High, Low, Jack, Game)") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<match.units.count, id: \.self) { i in
                            WheelColumn(title: match.units[i].name, value: $pts[i], range: 0...4)
                        }
                    }
                }
                Text("Total \(sum) of 4")
                    .font(.caption)
                    .foregroundStyle(sum <= 4 ? Color.secondary : Color.red)
            }
            Section {
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
                .disabled(sum > 4)
            }
        }
    }
}
