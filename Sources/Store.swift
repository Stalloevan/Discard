import Foundation
import SwiftUI

struct Tally: Codable, Hashable {
    var played: Int = 0
    var won: Int = 0
}

struct Lineup: Codable, Identifiable, Hashable {
    var id = UUID()
    var names: [String]
    var lastUsed: Date = Date()
    var played: [String: Int] = [:]
    var wins: [String: [String: Int]] = [:]
}

struct Snapshot: Codable {
    var matches: [GameMatch] = []
    var lineups: [Lineup] = []
    var players: [String: [String: Tally]] = [:]
}

final class Store: ObservableObject {
    @Published var matches: [GameMatch] = []
    @Published var lineups: [Lineup] = []
    @Published var players: [String: [String: Tally]] = [:]

    private let url: URL

    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        url = dir.appendingPathComponent("cardscores.json")
        if let data = try? Data(contentsOf: url),
           let snap = try? JSONDecoder().decode(Snapshot.self, from: data) {
            matches = snap.matches
            lineups = snap.lineups
            players = snap.players
        }
    }

    func save() {
        let snap = Snapshot(matches: matches, lineups: lineups, players: players)
        if let data = try? JSONEncoder().encode(snap) {
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: Lineups

    func lineupKey(_ names: [String]) -> String {
        let lowered = names.map { $0.lowercased() }
        return lowered.sorted().joined(separator: "|")
    }

    private func touchLineup(_ names: [String]) {
        let key = lineupKey(names)
        if let i = lineups.firstIndex(where: { lineupKey($0.names) == key }) {
            lineups[i].lastUsed = Date()
            lineups[i].names = names
        } else {
            lineups.append(Lineup(names: names))
        }
    }

    func seriesWins(_ m: GameMatch) -> [(String, Int)] {
        let key = lineupKey(m.names)
        var wins: [String: Int] = [:]
        if let l = lineups.first(where: { lineupKey($0.names) == key }) {
            wins = l.wins[m.kind.rawValue] ?? [:]
        }
        return m.names.map { ($0, wins[$0] ?? 0) }
    }

    // MARK: Matches

    @discardableResult
    func startMatch(kind: GameKind, names: [String], dealer: Int, target: Int) -> UUID {
        let n = names.count
        let setup = GameRules.setup(kind, players: n)
        var units: [ScoreUnit] = []
        if setup.teams.isEmpty {
            for i in 0..<n {
                units.append(ScoreUnit(name: names[i], members: [i]))
            }
        } else {
            for (t, members) in setup.teams.enumerated() {
                let who = members.map { names[$0] }.joined(separator: " & ")
                units.append(ScoreUnit(name: "Team \(t + 1)", members: members, subtitle: who))
            }
        }
        var m = GameMatch(kind: kind, names: names, units: units, dealer: dealer, target: target)
        if kind == .cribbage {
            m.pegs = Array(repeating: Peg(), count: n)
        }
        if kind == .war {
            m.cards = Array(repeating: GameRules.warPer(n), count: n)
        }
        matches.insert(m, at: 0)
        touchLineup(names)
        save()
        return m.id
    }

    func mutate(_ id: UUID, _ body: (inout GameMatch) -> Void) {
        guard let i = matches.firstIndex(where: { $0.id == id }) else { return }
        var m = matches[i]
        body(&m)
        matches[i] = m
        save()
    }

    func addRound(_ id: UUID, _ round: ScoreRound) {
        mutate(id) { m in
            var r = round
            r.dealer = m.dealer
            m.rounds.append(r)
            if !m.names.isEmpty {
                m.dealer = (m.dealer + 1) % m.names.count
            }
        }
    }

    func delete(_ id: UUID) {
        matches.removeAll { $0.id == id }
        save()
    }

    func finish(_ id: UUID, winners: [Int]) {
        guard let i = matches.firstIndex(where: { $0.id == id }) else { return }
        if matches[i].finished { return }
        var m = matches[i]
        m.finished = true
        m.finishedAt = Date()
        m.winnerUnits = winners
        matches[i] = m

        var winnerNames: Set<String> = []
        for u in winners where u < m.units.count {
            for s in m.units[u].members {
                winnerNames.insert(m.names[s])
            }
        }
        for name in m.names {
            var perGame: [String: Tally] = players[name] ?? [:]
            var t: Tally = perGame[m.kind.rawValue] ?? Tally()
            t.played += 1
            if winnerNames.contains(name) { t.won += 1 }
            perGame[m.kind.rawValue] = t
            players[name] = perGame
        }
        let key = lineupKey(m.names)
        if let li = lineups.firstIndex(where: { lineupKey($0.names) == key }) {
            let raw = m.kind.rawValue
            lineups[li].played[raw] = (lineups[li].played[raw] ?? 0) + 1
            var w: [String: Int] = lineups[li].wins[raw] ?? [:]
            for name in winnerNames {
                w[name] = (w[name] ?? 0) + 1
            }
            lineups[li].wins[raw] = w
        }
        save()
    }

    func playAgain(from m: GameMatch) -> UUID {
        let next = m.names.isEmpty ? 0 : (m.dealer + 1) % m.names.count
        return startMatch(kind: m.kind, names: m.names, dealer: next, target: m.target)
    }
}
