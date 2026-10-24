import SwiftUI

struct MatchView: View {
    let matchID: UUID
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var showEntry = false
    @State private var showRules = false
    @State private var showWinnerPicker = false
    @State private var confirmDelete = false

    private var match: GameMatch? {
        return store.matches.first { $0.id == matchID }
    }

    var body: some View {
        Group {
            if let m = match {
                content(m)
            } else {
                Text("This game was removed.")
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
    }

    @ViewBuilder
    private func content(_ m: GameMatch) -> some View {
        List {
            banner(m)
            scoreboard(m)
            dealerSection(m)

            if m.kind == .cribbage {
                CribbageView(matchID: matchID)
            } else if m.kind == .war {
                WarView(matchID: matchID)
            } else {
                roundsSection(m)
            }
        }
        .navigationTitle(m.kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showRules = true
                    } label: {
                        Label("Rules & setup", systemImage: "book")
                    }
                    if !m.finished {
                        Button {
                            showWinnerPicker = true
                        } label: {
                            Label("Declare winner…", systemImage: "trophy")
                        }
                    }
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Delete game", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEntry) {
            RoundEntryView(matchID: matchID)
                .environmentObject(store)
        }
        .sheet(isPresented: $showRules) {
            NavigationStack {
                RulesView(kind: m.kind, players: m.names.count)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showRules = false }
                        }
                    }
            }
        }
        .confirmationDialog("Who won?", isPresented: $showWinnerPicker, titleVisibility: .visible) {
            ForEach(Array(m.units.enumerated()), id: \.offset) { item in
                Button(item.element.name) {
                    store.finish(matchID, winners: [item.offset])
                }
            }
        }
        .confirmationDialog("Delete this game?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                store.delete(matchID)
                dismiss()
            }
        }
    }

    // MARK: Banner

    private func winnerNames(_ m: GameMatch, _ winners: [Int]) -> String {
        let names = winners.filter { $0 < m.units.count }.map { m.units[$0].name }
        return names.joined(separator: " & ")
    }

    private func skunkText(_ m: GameMatch) -> String {
        if m.kind != .cribbage { return "" }
        let lo = m.totals.min() ?? 0
        if m.target >= 121 {
            if lo < 61 { return " Double skunk!" }
            if lo < 91 { return " Skunk!" }
        }
        return ""
    }

    @ViewBuilder
    private func banner(_ m: GameMatch) -> some View {
        if m.finished {
            Section {
                Label("Winner: \(winnerNames(m, m.winnerUnits))\(skunkText(m))", systemImage: "trophy.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Button {
                    _ = store.playAgain(from: m)
                    dismiss()
                } label: {
                    Label("Play again with the same players", systemImage: "arrow.clockwise")
                }
            }
        } else if let w = m.suggestedWinners {
            Section {
                Label("\(winnerNames(m, w)) \(w.count > 1 ? "are" : "is") ahead at the finish", systemImage: "flag.checkered")
                    .font(.headline)
                Button {
                    store.finish(matchID, winners: w)
                } label: {
                    Label("Declare winner\(skunkText(m))", systemImage: "trophy")
                }
            }
        }
    }

    // MARK: Scoreboard

    private func scoreboard(_ m: GameMatch) -> some View {
        let leaders = m.leaders
        return Section {
            ForEach(Array(m.units.enumerated()), id: \.offset) { item in
                let idx = item.offset
                let u = item.element
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(seatColors[idx % 8])
                                .frame(width: 10, height: 10)
                            Text(u.name)
                                .font(.headline)
                            if u.members.contains(m.dealer) {
                                Image(systemName: "rectangle.stack.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if !u.subtitle.isEmpty {
                            Text(u.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if m.kind == .spades {
                            Text("Bags \(m.bags(idx)) / 10")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if m.kind == .war {
                            Text("cards")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text("\(m.total(idx))")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(leaders.contains(idx) && leaders.count < m.units.count ? Color.accentColor : Color.primary)
                }
            }
        } header: {
            Text(scoreHeader(m))
        } footer: {
            Text(seriesText(m))
        }
    }

    private func scoreHeader(_ m: GameMatch) -> String {
        switch m.kind {
        case .hearts: return "Scoreboard · lowest wins · game ends at \(m.target)"
        case .ohHell: return "Scoreboard"
        case .war: return "Cards held"
        default: return "Scoreboard · first to \(m.target)"
        }
    }

    private func seriesText(_ m: GameMatch) -> String {
        let wins = store.seriesWins(m)
        let parts = wins.map { "\($0.0) \($0.1)" }
        return "Games won with this lineup: " + parts.joined(separator: " · ")
    }

    // MARK: Dealer

    private func dealerSection(_ m: GameMatch) -> some View {
        let dealerName = m.dealer < m.names.count ? m.names[m.dealer] : ""
        return Section("Dealer") {
            HStack {
                Label(dealerName, systemImage: "rectangle.stack.fill")
                    .font(.headline)
                Spacer()
                Button("Next dealer") {
                    store.mutate(matchID) { mm in
                        mm.dealer = (mm.dealer + 1) % mm.names.count
                    }
                }
                .buttonStyle(.borderless)
            }
            if m.kind == .cribbage {
                Text("Crib: \(GameRules.cribSize(m.names.count)) cards, counted by \(dealerName).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Picker("Change dealer", selection: Binding(
                get: { m.dealer },
                set: { newValue in
                    store.mutate(matchID) { mm in
                        mm.dealer = newValue
                    }
                }
            )) {
                ForEach(0..<m.names.count, id: \.self) { i in
                    Text(m.names[i]).tag(i)
                }
            }
        }
    }

    // MARK: Rounds

    private func roundSummary(_ m: GameMatch, _ r: ScoreRound) -> String {
        var parts: [String] = []
        for (i, s) in r.scores.enumerated() where i < m.units.count {
            parts.append("\(m.units[i].name) \(signed(s))")
        }
        return parts.joined(separator: "  ·  ")
    }

    private func roundsSection(_ m: GameMatch) -> some View {
        let reversed = Array(m.rounds.enumerated().reversed())
        return Section {
            if !m.finished {
                if m.kind == .ohHell {
                    if let h = m.currentHand {
                        Text("Round \(m.rounds.count + 1) of \(m.ohHellHands.count): deal \(h) card\(h == 1 ? "" : "s") each")
                            .font(.subheadline)
                        Button {
                            showEntry = true
                        } label: {
                            Label("Enter round results", systemImage: "plus.circle.fill")
                        }
                    } else {
                        Text("All rounds played.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button {
                        showEntry = true
                    } label: {
                        Label("Add round", systemImage: "plus.circle.fill")
                    }
                }
            }
            if m.rounds.isEmpty {
                Text("No rounds yet")
                    .foregroundStyle(.secondary)
            }
            ForEach(reversed, id: \.element.id) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text("Round \(item.offset + 1)")
                        .font(.subheadline.bold())
                    Text(roundSummary(m, item.element))
                        .font(.caption)
                    if !item.element.detail.isEmpty {
                        Text(item.element.detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in
                let ids = offsets.map { reversed[$0].element.id }
                store.mutate(matchID) { mm in
                    mm.rounds.removeAll { ids.contains($0.id) }
                }
            }
        } header: {
            Text("Rounds")
        }
    }
}
