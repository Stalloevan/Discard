import SwiftUI

struct MatchView: View {
    let matchID: UUID
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var showRules = false
    @State private var showHistory = false
    @State private var showWinnerPicker = false
    @State private var confirmDelete = false

    private var match: GameMatch? {
        return store.matches.first { $0.id == matchID }
    }

    var body: some View {
        ZStack {
            FeltBackground()
            if let m = match {
                content(m)
            } else {
                Text("This game was removed.")
                    .foregroundColor(.white)
            }
        }
        .gcTitle(match?.kind.title ?? "Game")
        .gcNavigation()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showRules = true
                } label: {
                    Image(systemName: "book")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let m = match, m.kind != .cribbage && m.kind != .war {
                        Button {
                            showHistory = true
                        } label: {
                            Label("Round history", systemImage: "list.bullet")
                        }
                    }
                    if let m = match, !m.finished {
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
        .sheet(isPresented: $showRules) {
            if let m = match {
                RulesSheet(kind: m.kind, players: m.names.count)
            }
        }
        .sheet(isPresented: $showHistory) {
            HistorySheet(matchID: matchID)
                .environmentObject(store)
        }
        .confirmationDialog("Who won?", isPresented: $showWinnerPicker, titleVisibility: .visible) {
            if let m = match {
                ForEach(Array(m.units.enumerated()), id: \.offset) { item in
                    Button(item.element.name) {
                        store.finish(matchID, winners: [item.offset])
                    }
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

    @ViewBuilder
    private func content(_ m: GameMatch) -> some View {
        VStack(spacing: 8) {
            ScoreStrip(m: m)
            DealerBar(m: m, matchID: matchID)
            banner(m)
            switch m.kind {
            case .cribbage:
                CribbageBoardView(matchID: matchID)
                    .panel()
                    .frame(maxHeight: .infinity)
            case .war:
                ScrollView {
                    WarPanel(matchID: matchID)
                        .panel()
                }
                .scrollBounceBehavior(.basedOnSize)
            default:
                ScrollView {
                    RoundPanel(matchID: matchID)
                        .panel()
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

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
            HStack {
                Label("\(winnerNames(m, m.winnerUnits)) won!\(skunkText(m))", systemImage: "trophy.fill")
                    .font(.subheadline.bold())
                    .foregroundColor(GC.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Button("Play again") {
                    _ = store.playAgain(from: m)
                    dismiss()
                }
                .buttonStyle(GlossButtonStyle(compact: true))
            }
            .panel()
        } else if let w = m.suggestedWinners {
            HStack {
                Label("\(winnerNames(m, w)) \(w.count > 1 ? "lead" : "leads") at the finish", systemImage: "flag.checkered")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Button("Declare winner") {
                    store.finish(matchID, winners: w)
                }
                .buttonStyle(GlossButtonStyle(tint: Color(red: 0.75, green: 0.50, blue: 0.10), compact: true))
            }
            .panel()
        }
    }
}

struct HistorySheet: View {
    let matchID: UUID
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    private var match: GameMatch? {
        return store.matches.first { $0.id == matchID }
    }

    private func summary(_ m: GameMatch, _ r: ScoreRound) -> String {
        var parts: [String] = []
        for (i, s) in r.scores.enumerated() where i < m.units.count {
            parts.append("\(m.units[i].name) \(signed(s))")
        }
        return parts.joined(separator: "  ·  ")
    }

    var body: some View {
        NavigationStack {
            Group {
                if let m = match {
                    let reversed = Array(m.rounds.enumerated().reversed())
                    List {
                        if reversed.isEmpty {
                            Text("No rounds yet")
                                .foregroundColor(GC.dim)
                        }
                        ForEach(reversed, id: \.element.id) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Round \(item.offset + 1)")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Text(summary(m, item.element))
                                    .font(.caption)
                                    .foregroundColor(.white)
                                if !item.element.detail.isEmpty {
                                    Text(item.element.detail)
                                        .font(.caption2)
                                        .foregroundColor(GC.dim)
                                }
                            }
                            .listRowBackground(Color.black.opacity(0.3))
                        }
                        .onDelete { offsets in
                            let ids = offsets.map { reversed[$0].element.id }
                            store.mutate(matchID) { mm in
                                mm.rounds.removeAll { ids.contains($0.id) }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                } else {
                    Text("Game not found.")
                }
            }
            .background(FeltBackground())
            .gcTitle("Round history")
            .gcNavigation()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
