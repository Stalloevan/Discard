import Foundation

struct RuleSection: Identifiable {
    let id = UUID()
    let title: String
    let lines: [String]
}

struct Setup {
    var decks: String
    var removed: String
    var hand: String
    var play: [String]
    var teams: [[Int]]
    var target: Int
}

enum GameRules {

    // MARK: Helpers

    static func teams(_ n: Int, _ count: Int) -> [[Int]] {
        var out: [[Int]] = []
        for t in 0..<count {
            var members: [Int] = []
            for s in 0..<n where s % count == t {
                members.append(s)
            }
            out.append(members)
        }
        return out
    }

    static func ohHellMax(_ n: Int) -> Int {
        if n <= 5 { return 10 }
        if n == 6 { return 8 }
        if n == 7 { return 7 }
        return 6
    }

    static func warPer(_ n: Int) -> Int {
        let table: [Int: Int] = [2: 26, 3: 17, 4: 13, 5: 10, 6: 8, 7: 7, 8: 6]
        return table[n] ?? 13
    }

    static func cribSize(_ n: Int) -> Int {
        return n <= 4 ? 4 : n
    }

    static func handSize(_ kind: GameKind, _ n: Int) -> Int {
        switch kind {
        case .hearts:
            let table: [Int: Int] = [3: 17, 4: 13, 5: 10, 6: 8, 7: 7, 8: 6]
            return table[n] ?? 13
        case .spades:
            let table: [Int: Int] = [2: 13, 3: 17, 4: 13, 5: 10, 6: 8, 7: 7, 8: 6]
            return table[n] ?? 13
        case .highLowJack:
            return 6
        case .euchre:
            return n == 8 ? 4 : 5
        case .ohHell:
            return ohHellMax(n)
        case .war:
            return warPer(n)
        case .cribbage:
            return (n == 2 || n >= 5) ? 6 : 5
        }
    }

    // MARK: Setup per player count

    static func setup(_ kind: GameKind, players n: Int) -> Setup {
        switch kind {
        case .hearts: return heartsSetup(n)
        case .cribbage: return cribbageSetup(n)
        case .highLowJack: return hljSetup(n)
        case .war: return warSetup(n)
        case .spades: return spadesSetup(n)
        case .ohHell: return ohHellSetup(n)
        case .euchre: return euchreSetup(n)
        }
    }

    private static func heartsSetup(_ n: Int) -> Setup {
        let removedTable: [Int: String] = [
            3: "2♦ (1 card)",
            4: "None",
            5: "2♦, 2♣ (2 cards)",
            6: "2♦, 2♣, 3♦, 3♣ (4 cards)",
            7: "2♦, 2♣, 2♠ (3 cards)",
            8: "2♦, 2♣, 2♠, 3♦ (4 cards)"
        ]
        let per = handSize(.hearts, n)
        let passCount = n == 8 ? 2 : 3
        var dir = "left, right, then hold (no pass)"
        if n == 4 { dir = "left, right, across, then hold (no pass)" }
        var play: [String] = []
        play.append("Pass \(passCount) cards face-down before each hand: \(dir).")
        play.append("The holder of the lowest club (the 2♣ unless it was removed) leads the first trick.")
        play.append("All 26 penalty points stay in the deck: 13 hearts and the Q♠.")
        let hand = "\(per) cards each (\(per * n) dealt)"
        return Setup(decks: "1 standard 52-card deck", removed: removedTable[n] ?? "None", hand: hand, play: play, teams: [], target: 100)
    }

    private static func cribbageSetup(_ n: Int) -> Setup {
        var hand = ""
        var play: [String] = []
        switch n {
        case 2:
            hand = "6 cards each; discard 2 to the crib; keep 4"
            play.append("Each player discards 2 cards, so the crib has 4 cards.")
        case 3:
            hand = "5 cards each, plus 1 card dealt to the crib; discard 1; keep 4"
            play.append("Deal one extra card face-down to the crib, then each player discards 1. Crib = 4 cards.")
        case 4:
            hand = "5 cards each; discard 1; keep 4"
            play.append("Each player discards 1 card, so the crib has 4 cards.")
        default:
            hand = "6 cards each; discard 1; keep 5"
            play.append("Each player discards 1 card, so the crib has \(n) cards (one from every player).")
            play.append("Hands and pegging use 5 cards each. The crib is counted in full with the starter.")
        }
        play.append("Play goes clockwise. The player left of the dealer leads the pegging; the dealer counts last, then the crib.")
        play.append("Cut the starter card after all discards. Cards not dealt stay in the deck.")
        return Setup(decks: "1 standard 52-card deck", removed: "None", hand: hand, play: play, teams: [], target: 121)
    }

    private static func hljSetup(_ n: Int) -> Setup {
        let teamCount = n == 4 ? 2 : (n == 6 ? 3 : (n == 8 ? 4 : 0))
        var t: [[Int]] = []
        if teamCount > 0 { t = teams(n, teamCount) }
        var play: [String] = []
        play.append("Deal 6 cards each (three at a time). \(52 - 6 * n) cards stay in the deck unused.")
        play.append("Bidding starts left of the dealer: bid 1–4 or pass. The dealer may take the bid on a tie.")
        if teamCount > 0 {
            play.append("Partners sit directly across and share a score.")
        } else {
            play.append("Every player scores for themselves.")
        }
        play.append("Points per hand: High, Low, Jack, Game (4 total).")
        return Setup(decks: "1 standard 52-card deck", removed: "None", hand: "6 cards each", play: play, teams: t, target: 11)
    }

    private static func warSetup(_ n: Int) -> Setup {
        let removedTable: [Int: String] = [
            2: "None",
            3: "One 2",
            4: "None",
            5: "Two 2s",
            6: "Four 2s",
            7: "Three 2s",
            8: "Four 2s"
        ]
        let per = warPer(n)
        var play: [String] = []
        play.append("Deal every card so all players hold \(per).")
        if n > 2 {
            play.append("Everyone flips together. If the top cards tie, only the tied players go to war.")
        } else {
            play.append("Both players flip together; a tie is a war.")
        }
        play.append("War: each tied player lays 3 cards face-down and flips a fourth. Highest wins the whole pile.")
        play.append("A player with too few cards for a war flips their last card.")
        return Setup(decks: "1 standard 52-card deck", removed: removedTable[n] ?? "None", hand: "\(per) cards each (\(per * n) in play)", play: play, teams: [], target: 0)
    }

    private static func spadesSetup(_ n: Int) -> Setup {
        let removedTable: [Int: String] = [
            2: "None, but 26 cards are set aside unused",
            3: "2♣ (1 card)",
            4: "None",
            5: "2♣, 2♦ (2 cards)",
            6: "2♣, 2♦, 3♣, 3♦ (4 cards)",
            7: "2♣, 2♦, 3♦ (3 cards)",
            8: "2♣, 2♦, 3♣, 3♦ (4 cards)"
        ]
        let per = handSize(.spades, n)
        let teamCount = n == 4 ? 2 : (n == 6 ? 3 : (n == 8 ? 4 : 0))
        var t: [[Int]] = []
        if teamCount > 0 { t = teams(n, teamCount) }
        var play: [String] = []
        play.append("Each hand has \(per) tricks. Spades are always trump.")
        if teamCount > 0 {
            play.append("Partners sit directly across. Team bid = both partners' bids added together.")
        } else {
            play.append("Every player bids and scores for themselves.")
        }
        play.append("Spades cannot be led until broken.")
        return Setup(decks: "1 standard 52-card deck", removed: removedTable[n] ?? "None", hand: "\(per) cards each", play: play, teams: t, target: 500)
    }

    private static func ohHellSetup(_ n: Int) -> Setup {
        let m = ohHellMax(n)
        var play: [String] = []
        play.append("Round 1 deals \(m) cards each. Hands shrink to 1, then grow back to \(m): \(2 * m - 1) rounds.")
        play.append("After dealing, turn the next card face-up. Its suit is trump.")
        play.append("The dealer rotates every round and bids last. Total bids may not equal the number of tricks.")
        play.append("Round 1 leaves \(52 - m * n) cards undealt.")
        return Setup(decks: "1 standard 52-card deck", removed: "None", hand: "\(m) cards in round 1, then 1 fewer each round", play: play, teams: [], target: 0)
    }

    private static func euchreSetup(_ n: Int) -> Setup {
        let sizes: [Int: Int] = [2: 24, 3: 24, 4: 24, 5: 28, 6: 32, 7: 36, 8: 36]
        let ranks: [Int: String] = [2: "9–A", 3: "9–A", 4: "9–A", 5: "8–A", 6: "7–A", 7: "6–A", 8: "6–A"]
        let removedTable: [Int: String] = [
            2: "All 2s–8s (28 cards)",
            3: "All 2s–8s (28 cards)",
            4: "All 2s–8s (28 cards)",
            5: "All 2s–7s (24 cards)",
            6: "All 2s–6s (20 cards)",
            7: "All 2s–5s (16 cards)",
            8: "All 2s–5s (16 cards)"
        ]
        let size = sizes[n] ?? 24
        let per = handSize(.euchre, n)
        let left = size - n * per
        var t: [[Int]] = []
        if n == 4 || n == 6 || n == 8 { t = teams(n, 2) }
        var play: [String] = []
        play.append("Play with the \(ranks[n] ?? "9–A") cards only (\(size) cards).")
        play.append("Deal \(per) each. \(left) cards are left; turn the top one face-up for the trump round.")
        play.append("Makers need \(per / 2 + 1) of \(per) tricks.")
        if n == 4 {
            play.append("Two teams of two; partners sit across.")
        } else if n == 6 {
            play.append("Two teams of three; seats alternate between the teams.")
        } else if n == 8 {
            play.append("Two teams of four; seats alternate between the teams.")
        } else {
            play.append("Every player is on their own: the makers play against everyone else.")
        }
        return Setup(decks: "1 standard 52-card deck, trimmed to \(size) cards", removed: removedTable[n] ?? "None", hand: "\(per) cards each", play: play, teams: t, target: 10)
    }

    // MARK: General rules

    static func overview(_ kind: GameKind) -> [RuleSection] {
        switch kind {
        case .hearts:
            return [
                RuleSection(title: "Goal", lines: [
                    "Take as few points as possible. When any player reaches the target (default 100) the game ends and the lowest score wins."
                ]),
                RuleSection(title: "Play", lines: [
                    "Pass cards face-down at the start of each hand. The direction rotates.",
                    "Follow suit if you can. On the first trick, avoid playing hearts or the Q♠ if you have anything else.",
                    "Hearts cannot be led until a heart has been played (broken).",
                    "The winner of a trick leads the next one."
                ]),
                RuleSection(title: "Scoring", lines: [
                    "Each heart is 1 point and the Q♠ is 13, so every hand adds up to 26.",
                    "Shoot the moon: take all 13 hearts and the Q♠. You score 0 and everyone else scores 26. (Some groups subtract 26 from the shooter instead.)",
                    "In the app, enter the points each player took; the hand must total exactly 26. Entering 26 for one player is shooting the moon: they score 0 and everyone else scores 26."
                ])
            ]
        case .cribbage:
            return [
                RuleSection(title: "Goal", lines: [
                    "First to 121 points wins (61 for a short game). Reaching the finish while an opponent is under 91 is a skunk, and under 61 a double skunk."
                ]),
                RuleSection(title: "Each deal", lines: [
                    "Deal, then discard to the dealer's crib (the number depends on how many are playing).",
                    "Cut the starter card. If it is a Jack, the dealer pegs 2 (his heels).",
                    "Pegging: take turns playing cards, keeping a running count that cannot pass 31.",
                    "Show: count each hand starting left of the dealer. The dealer counts their hand, then the crib."
                ]),
                RuleSection(title: "Pegging points", lines: [
                    "Count of 15: 2. Count of 31: 2.",
                    "Pair 2, three of a kind 6, four of a kind 12.",
                    "Run of 3 or more cards (any order): 1 per card.",
                    "Go: 1 point for the last card when no one can play. Last card of a count of 31 scores its 2 instead."
                ]),
                RuleSection(title: "The show", lines: [
                    "Each combination of cards totalling 15: 2 points.",
                    "Pairs 2, triples 6, quadruples 12.",
                    "Runs: 1 per card in the run.",
                    "Flush: 4 cards in your hand 4 points, 5 with the starter 5 points. A crib needs all 5.",
                    "Nobs: a Jack in your hand matching the starter's suit scores 1."
                ]),
                RuleSection(title: "Peg board", lines: [
                    "Tap a hole on a player's track to place their front peg. The old front peg becomes the back peg, and the points between the two are shown."
                ])
            ]
        case .highLowJack:
            return [
                RuleSection(title: "Goal", lines: [
                    "First to 11 points (adjustable) wins. If both sides reach it in one hand, the bidding side wins."
                ]),
                RuleSection(title: "Points each hand", lines: [
                    "High: whoever holds the highest trump out.",
                    "Low: whoever was dealt the lowest trump.",
                    "Jack: whoever wins the Jack of trump in a trick.",
                    "Game: most card points taken: Ace 4, King 3, Queen 2, Jack 1, Ten 10."
                ]),
                RuleSection(title: "Bidding and play", lines: [
                    "Starting left of the dealer, bid 1–4 or pass. The dealer may take the bid on a tie.",
                    "The high bidder leads; the suit of the first card led is trump.",
                    "You must follow suit or may play a trump."
                ]),
                RuleSection(title: "Scoring", lines: [
                    "Each side adds the points it won. A bidder who wins fewer points than the bid loses the bid amount (the score can go negative).",
                    "If the Jack is not in play, it is simply not scored."
                ])
            ]
        case .war:
            return [
                RuleSection(title: "Goal", lines: [
                    "Win every card."
                ]),
                RuleSection(title: "Play", lines: [
                    "Everyone flips their top card at once. The highest card (Ace high) takes all of the flipped cards.",
                    "Tie: those players go to war. Each lays 3 face-down and flips another. Highest wins the pile; another tie repeats the war.",
                    "Winners put won cards under their stack. Strategy option: winners may arrange the won cards in any order first."
                ]),
                RuleSection(title: "In the app", lines: [
                    "Set each player's card count with the wheels. The counts must add up to the cards in play.",
                    "A player at 0 is out. The last player holding cards wins."
                ])
            ]
        case .spades:
            return [
                RuleSection(title: "Goal", lines: [
                    "First to 500 points (adjustable). A side that falls to −200 loses."
                ]),
                RuleSection(title: "Bidding and play", lines: [
                    "Each player bids the number of tricks they expect. Partners' bids add together.",
                    "Nil: bid to take no tricks. Blind nil is bid before looking at your cards.",
                    "Spades are trump and cannot be led until broken."
                ]),
                RuleSection(title: "Scoring", lines: [
                    "Made bid: 10 points per trick bid, plus 1 for each extra trick (a bag).",
                    "Missed bid: −10 points per trick bid.",
                    "Every 10 bags: −100 points.",
                    "Nil made +100, nil failed −100. Blind nil is ±200: enter it as two nils."
                ]),
                RuleSection(title: "In the app", lines: [
                    "For each side enter the bid, tricks taken, and any nils made or failed. Bags are tracked for you."
                ])
            ]
        case .ohHell:
            return [
                RuleSection(title: "Goal", lines: [
                    "Bid exactly how many tricks you will take. Highest score after the last round wins."
                ]),
                RuleSection(title: "Play", lines: [
                    "The hand size goes down one each round to 1, then back up.",
                    "After dealing, turn up a card to set trump.",
                    "Bidding starts left of the dealer. The dealer bids last and may not make the total equal the number of tricks.",
                    "The player left of the dealer leads. Follow suit if you can; the highest trump or highest card of the led suit wins."
                ]),
                RuleSection(title: "Scoring", lines: [
                    "Exact bid: 10 points plus your bid. Any other result: 0 points.",
                    "Optional house rule: lose 1 point for each trick you were off. Edit the round score if you play this way."
                ])
            ]
        case .euchre:
            return [
                RuleSection(title: "Goal", lines: [
                    "First side to 10 points wins."
                ]),
                RuleSection(title: "Cards", lines: [
                    "Trimmed deck (see setup). Trump order: Jack of trump (right bower), Jack of the same colour (left bower), then A, K, Q, 10, 9 of trump. Other suits rank A high."
                ]),
                RuleSection(title: "Bidding", lines: [
                    "Left of the dealer, each player may order up the turned-up card (its suit becomes trump) or pass.",
                    "If all pass, a second round lets players name a different suit. If everyone passes again, redeal.",
                    "A maker may go alone, sitting out their partner."
                ]),
                RuleSection(title: "Scoring", lines: [
                    "Makers win the majority of tricks: 1 point.",
                    "Makers win every trick (march): 2 points. Alone and march: 4 points.",
                    "Euchre (makers fail to win a majority): the defenders score 2 points."
                ])
            ]
        }
    }
}
