import Foundation

enum GameKind: String, Codable, CaseIterable, Identifiable {
    case hearts, cribbage, highLowJack, war, spades, ohHell, euchre

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hearts: return "Hearts"
        case .cribbage: return "Cribbage"
        case .highLowJack: return "High-Low-Jack"
        case .war: return "War"
        case .spades: return "Spades"
        case .ohHell: return "Oh Hell"
        case .euchre: return "Euchre"
        }
    }

    var symbol: String {
        switch self {
        case .hearts: return "suit.heart.fill"
        case .cribbage: return "circle.grid.3x3.fill"
        case .highLowJack: return "arrow.up.arrow.down"
        case .war: return "bolt.fill"
        case .spades: return "suit.spade.fill"
        case .ohHell: return "flame.fill"
        case .euchre: return "suit.club.fill"
        }
    }

    var blurb: String {
        switch self {
        case .hearts: return "Dodge the points. Lowest score wins."
        case .cribbage: return "Peg board to 121 with crib and dealer tracking."
        case .highLowJack: return "Four points a hand: High, Low, Jack, Game."
        case .war: return "Card counts for every player."
        case .spades: return "Bid tricks, avoid bags, partner up."
        case .ohHell: return "Bid exactly. Hands shrink, then grow."
        case .euchre: return "Trump, bowers and going alone."
        }
    }

    var lowWins: Bool { self == .hearts }

    var minPlayers: Int { self == .hearts ? 3 : 2 }
}

struct ScoreUnit: Codable, Hashable {
    var name: String
    var members: [Int]
    var subtitle: String = ""
}

struct ScoreRound: Codable, Identifiable, Hashable {
    var id = UUID()
    var scores: [Int]
    var extra: [Int] = []
    var detail: String = ""
    var dealer: Int = 0
}

struct Peg: Codable, Hashable {
    var front: Int = 0
    var back: Int = 0
}

struct GameMatch: Codable, Identifiable {
    var id = UUID()
    var kind: GameKind
    var names: [String]
    var units: [ScoreUnit]
    var dealer: Int = 0
    var target: Int
    var rounds: [ScoreRound] = []
    var pegs: [Peg] = []
    var pegHistory: [[Peg]] = []
    var cards: [Int] = []
    var startedAt: Date = Date()
    var finished: Bool = false
    var finishedAt: Date? = nil
    var winnerUnits: [Int] = []
}

extension GameMatch {
    func total(_ u: Int) -> Int {
        switch kind {
        case .cribbage:
            return u < pegs.count ? pegs[u].front : 0
        case .war:
            return u < cards.count ? cards[u] : 0
        default:
            var t = 0
            for r in rounds where u < r.scores.count {
                t += r.scores[u]
            }
            return t
        }
    }

    func bags(_ u: Int) -> Int {
        var t = 0
        for r in rounds where u < r.extra.count {
            t += r.extra[u]
        }
        return t
    }

    var totals: [Int] {
        var out: [Int] = []
        for u in 0..<units.count {
            out.append(total(u))
        }
        return out
    }

    var ohHellHands: [Int] {
        let m = GameRules.ohHellMax(names.count)
        var seq: [Int] = []
        var h = m
        while h >= 1 {
            seq.append(h)
            h -= 1
        }
        if m >= 2 {
            for x in 2...m {
                seq.append(x)
            }
        }
        return seq
    }

    var currentHand: Int? {
        let hands = ohHellHands
        return rounds.count < hands.count ? hands[rounds.count] : nil
    }

    var leaders: [Int] {
        let t = totals
        if t.isEmpty { return [] }
        let best = kind.lowWins ? (t.min() ?? 0) : (t.max() ?? 0)
        var out: [Int] = []
        for i in 0..<t.count where t[i] == best {
            out.append(i)
        }
        return out
    }

    var suggestedWinners: [Int]? {
        let t = totals
        if t.isEmpty { return nil }
        let mx = t.max() ?? 0
        let lo = t.min() ?? 0
        var out: [Int] = []
        switch kind {
        case .hearts:
            if mx < target { return nil }
            for i in 0..<t.count where t[i] == lo { out.append(i) }
            return out
        case .cribbage, .highLowJack, .euchre:
            if mx < target { return nil }
            for i in 0..<t.count where t[i] == mx { out.append(i) }
            return out
        case .spades:
            if mx >= target || lo <= -200 {
                for i in 0..<t.count where t[i] == mx { out.append(i) }
                return out
            }
            return nil
        case .ohHell:
            if rounds.count >= ohHellHands.count && !rounds.isEmpty {
                for i in 0..<t.count where t[i] == mx { out.append(i) }
                return out
            }
            return nil
        case .war:
            var holders: [Int] = []
            for i in 0..<t.count where t[i] > 0 { holders.append(i) }
            if holders.count == 1 { return holders }
            return nil
        }
    }
}
