import Foundation

enum Mark: String, Codable {
    case x = "X", o = "O"
    var other: Mark { self == .x ? .o : .x }
}

struct GameEvent: Codable {
    var type: String      // "join", "move", "reset"
    var pid: String
    var cell: Int?
    var round: Int?
}

/// Deterministic state built by replaying the room's event log, so every client converges on the same game.
struct GameState {
    static let lines = [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]]

    var players: [String] = []          // players[0] = X, players[1] = O
    var board: [Mark?] = Array(repeating: nil, count: 9)
    var round = 0
    var turn: Mark = .x
    var winner: Mark?
    var winLine: [Int] = []
    var scoreX = 0
    var scoreO = 0

    var isDraw: Bool { winner == nil && !board.contains(where: { $0 == nil }) }
    var isOver: Bool { winner != nil || isDraw }

    func mark(for pid: String) -> Mark? {
        guard let i = players.firstIndex(of: pid) else { return nil }
        return i == 0 ? .x : .o
    }

    mutating func apply(_ e: GameEvent) {
        switch e.type {
        case "join":
            if players.count < 2, !players.contains(e.pid) { players.append(e.pid) }
        case "move":
            guard players.count == 2, !isOver,
                  let cell = e.cell, (0..<9).contains(cell), board[cell] == nil,
                  e.round == round, mark(for: e.pid) == turn else { return }
            board[cell] = turn
            if let line = Self.lines.first(where: { l in l.allSatisfy { board[$0] == turn } }) {
                winner = turn
                winLine = line
                if turn == .x { scoreX += 1 } else { scoreO += 1 }
            } else {
                turn = turn.other
            }
        case "reset":
            guard isOver, e.round == round, players.contains(e.pid) else { return }
            round += 1
            board = Array(repeating: nil, count: 9)
            winner = nil
            winLine = []
            turn = round % 2 == 0 ? .x : .o
        default:
            break
        }
    }
}
