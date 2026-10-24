import SwiftUI

enum MatchOverlay {
    case menu, winner, delete, dealer
}

struct MatchView: View {
    let matchID: UUID
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var showRules = false
    @State private var showHistory = false
    @State private var overlay: MatchOverlay? = nil

    private var match: GameMatch? {
        return store.matches.first { $0.id == matchID }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                GCHeader(match?.kind.title ?? "Game") {
                    HeaderButton(symbol: "book") {
                        showRules = true
                    }
                    HeaderButton(symbol: "ellipsis.circle") {
                        overlay = .menu
                    }
                }
                ZStack {
                    if let m = match {
                        content(m)
                    } else {
                        Text("This game was removed.")
                            .foregroundColor(GC.onFelt)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .background(FeltBackground())

            if overlay != nil {
                FlatMenuOverlay(title: overlayTitle, actions: overlayActions, close: { overlay = nil })
            }
        }
        .gcNavigation()
        .fullScreenCover(isPresented: $showRules) {
            if let m = match {
                RulesSheet(kind: m.kind, players: m.names.count)
            }
        }
        .fullScreenCover(isPresented: $showHistory) {
            HistorySheet(matchID: matchID)
                .environmentObject(store)
        }
    }

    private var overlayTitle: String {
        switch overlay {
        case .winner: return "Who won?"
        case .delete: return "Delete this game?"
        case .dealer: return "Who deals?"
        default: return ""
        }
    }

    private var overlayActions: [FlatAction] {
        guard let m = match else { return [] }
        switch overlay {
        case .menu:
            var list: [FlatAction] = []
            if m.kind == .cribbage && !m.finished {
                list.append(FlatAction(title: "Undo last peg move") {
                    store.mutate(matchID) { mm in
                        if let last = mm.pegHistory.last {
                            mm.pegs = last
                            mm.pegHistory.removeLast()
                        }
                    }
                })
                list.append(FlatAction(title: "Reset the board", destructive: true) {
                    store.mutate(matchID) { mm in
                        mm.pegs = Array(repeating: Peg(), count: mm.names.count)
                        mm.pegHistory = []
                    }
                })
            }
            if m.kind != .cribbage && m.kind != .war {
                list.append(FlatAction(title: "Round history") {
                    showHistory = true
                })
            }
            if !m.finished {
                list.append(FlatAction(title: "Declare winner…") {
                    overlay = .winner
                })
            }
            list.append(FlatAction(title: "Delete game", destructive: true) {
                overlay = .delete
            })
            return list
        case .winner:
            return m.units.enumerated().map { item in
                FlatAction(title: item.element.name) {
                    store.finish(matchID, winners: [item.offset])
                }
            }
        case .delete:
            return [
                FlatAction(title: "Delete", destructive: true) {
                    store.delete(matchID)
                    dismiss()
                }
            ]
        case .dealer:
            return m.names.enumerated().map { item in
                FlatAction(title: item.element) {
                    store.mutate(matchID) { mm in
                        mm.dealer = item.offset
                    }
                }
            }
        case nil:
            return []
        }
    }

    @ViewBuilder
    private func content(_ m: GameMatch) -> some View {
        VStack(spacing: 6) {
            ScoreStrip(m: m)
            DealerBar(m: m, matchID: matchID, onChangeDealer: { overlay = .dealer })
            banner(m)
            switch m.kind {
            case .cribbage:
                CribbageBoardView(matchID: matchID)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 14).fill(GC.mantle))
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
        .padding(.top, 8)
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
                    .foregroundColor(GC.dim)
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
                    .foregroundColor(GC.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Button("Declare winner") {
                    store.finish(matchID, winners: w)
                }
                .buttonStyle(GlossButtonStyle(tint: GC.yellow, compact: true))
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
        VStack(spacing: 0) {
            GCHeader("Round history", showBack: false) {
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .foregroundColor(GC.onLeather)
                        .padding(.horizontal, 6)
                        .frame(height: 36)
                }
                .buttonStyle(.plain)
            }
            if let m = match {
                let reversed = Array(m.rounds.enumerated().reversed())
                List {
                    if reversed.isEmpty {
                        Text("No rounds yet")
                            .foregroundColor(GC.dim)
                            .listRowBackground(GC.mantle)
                    }
                    ForEach(reversed, id: \.element.id) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Round \(item.offset + 1)")
                                .font(.subheadline.bold())
                                .foregroundColor(GC.text)
                            Text(summary(m, item.element))
                                .font(.caption)
                                .foregroundColor(GC.text)
                            if !item.element.detail.isEmpty {
                                Text(item.element.detail)
                                    .font(.caption2)
                                    .foregroundColor(GC.dim)
                            }
                        }
                        .listRowBackground(GC.mantle)
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
                    .foregroundColor(GC.onFelt)
                    .frame(maxHeight: .infinity)
            }
        }
        .background(FeltBackground())
        .preferredColorScheme(.light)
    }
}
