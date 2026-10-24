import SwiftUI

enum MatchOverlay {
    case menu, winner, delete
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
        // Respects the safe area on purpose: that is how we learn where the notch is.
        GeometryReader { geo in
            let ins = geo.safeAreaInsets
            let fullW = geo.size.width + ins.leading + ins.trailing
            let fullH = geo.size.height + ins.top + ins.bottom
            // The whole game UI is laid out like a portrait screen, then turned a quarter turn (header on the left).
            // Portrait top/leading/bottom/trailing are the screen's left/bottom/right/top.
            // The notch side only needs to clear the cut-out (not the whole inset); the two long sides get the same margin.
            let side: CGFloat = -6   // tight, equal margins on both long sides (12 - 6 = 6pt)
            let pins = EdgeInsets(
                top: max(ins.leading - 22, 0),
                leading: side,
                bottom: max(ins.trailing - 22, 0),
                trailing: side
            )
            portraitUI(pins)
                .frame(width: fullH, height: fullW)
                .rotationEffect(.degrees(-90))
                .position(x: fullW / 2 - ins.leading, y: fullH / 2 - ins.top)
        }
        .background(FeltBackground())
        .gcNavigation()
        .onAppear {
            Orient.lock(.landscape)
        }
        .onDisappear {
            if !showRules && !showHistory {
                Orient.lock(.portrait)
            }
        }
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

    private func portraitUI(_ pins: EdgeInsets) -> some View {
        ZStack {
            VStack(spacing: 0) {
                if let m = match {
                    GCHeader(m.kind.title) {
                        HeaderButton(symbol: "book") {
                            showRules = true
                        }
                        HeaderButton(symbol: "ellipsis.circle") {
                            overlay = .menu
                        }
                    } below: {
                        ScoreStrip(m: m)
                    }
                    .icon(m.kind)
                    .insets(pins)
                } else {
                    GCHeader("Game")
                        .insets(pins)
                }
                ZStack(alignment: .top) {
                    if let m = match {
                        content(m)
                    } else {
                        Text("This game was removed.")
                            .foregroundColor(GC.onFelt)
                    }
                }
                .frame(maxHeight: .infinity)
                .padding(.leading, pins.leading)
                .padding(.trailing, pins.trailing)
                .padding(.bottom, pins.bottom)
            }

            if overlay != nil {
                FlatMenuOverlay(title: overlayTitle, actions: overlayActions, close: { overlay = nil })
            }
        }
    }

    private var overlayTitle: String {
        switch overlay {
        case .winner: return "Who won?"
        case .delete: return "Delete this game?"
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
                store.delete(matchID)
                dismiss()
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
        case nil:
            return []
        }
    }

    @ViewBuilder
    private func content(_ m: GameMatch) -> some View {
        VStack(spacing: 6) {
            banner(m)
            switch m.kind {
            case .cribbage:
                CribbageBoardView(matchID: matchID)
                    .frame(maxHeight: .infinity)
            case .war:
                WarPanel(matchID: matchID)
                    .frame(maxHeight: .infinity)
            case .euchre:
                ScrollView {
                    RoundPanel(matchID: matchID)
                }
                .scrollBounceBehavior(.basedOnSize)
            default:
                RoundPanel(matchID: matchID)
                    .frame(maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
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
