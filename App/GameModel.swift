import Foundation
import Observation

private struct RelayMessage: Decodable {
    var id: String
    var event: String
    var message: String?
}

/// Uses ntfy.sh as a free, account-less pub/sub relay: each room is a topic, each game action an event.
@MainActor
@Observable
final class GameModel {
    var inRoom = false
    var roomCode = ""
    var state = GameState()
    var connected = false
    var error: String?

    let pid = UUID().uuidString
    private var seen = Set<String>()
    private var lastId: String?
    private var streamTask: Task<Void, Never>?
    private var checkTask: Task<Void, Never>?
    private var isHost = false

    private let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 120
        c.timeoutIntervalForResource = 60 * 60 * 6
        return URLSession(configuration: c)
    }()

    var myMark: Mark? { state.mark(for: pid) }
    var canPlay: Bool { state.players.count == 2 && !state.isOver && myMark == state.turn }

    // MARK: Lobby actions

    func create() {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        let code = String((0..<6).map { _ in chars.randomElement()! })
        enter(code: code, host: true)
    }

    func join(code: String) {
        let c = code.trimmingCharacters(in: .whitespaces).uppercased()
        guard c.count == 6 else { error = "Enter a 6-character room code."; return }
        enter(code: c, host: false)
    }

    func leave() {
        streamTask?.cancel(); checkTask?.cancel()
        streamTask = nil; checkTask = nil
        inRoom = false; connected = false
        state = GameState(); seen = []; lastId = nil; roomCode = ""
    }

    // MARK: Game actions

    func play(_ cell: Int) {
        guard canPlay, state.board[cell] == nil else { return }
        send(GameEvent(type: "move", pid: pid, cell: cell, round: state.round))
    }

    func rematch() {
        guard state.isOver else { return }
        send(GameEvent(type: "reset", pid: pid, cell: nil, round: state.round))
    }

    // MARK: Networking

    private func url(_ suffix: String = "") -> URL {
        URL(string: "https://ntfy.sh/mobilecode-ttt-\(roomCode.lowercased())\(suffix)")!
    }

    private func enter(code: String, host: Bool) {
        leave()
        error = nil
        roomCode = code
        isHost = host
        inRoom = true
        startStream()
        if host {
            send(GameEvent(type: "join", pid: pid, cell: nil, round: nil))
        } else {
            checkTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(3))
                guard let self, !Task.isCancelled else { return }
                if self.state.players.isEmpty {
                    self.fail("Room not found.")
                } else if self.myMark == nil {
                    if self.state.players.count >= 2 {
                        self.fail("Room is full.")
                    } else {
                        self.send(GameEvent(type: "join", pid: self.pid, cell: nil, round: nil))
                    }
                }
            }
        }
    }

    private func fail(_ message: String) {
        leave()
        error = message
    }

    private func send(_ event: GameEvent) {
        guard let data = try? JSONEncoder().encode(event) else { return }
        var req = URLRequest(url: url())
        req.httpMethod = "POST"
        req.httpBody = data
        Task { [weak self] in
            guard let self else { return }
            do {
                let (_, resp) = try await self.session.data(for: req)
                if let h = resp as? HTTPURLResponse, h.statusCode >= 400 {
                    self.error = "Server rejected the move (\(h.statusCode))."
                }
            } catch {
                self.error = "Couldn't reach the server."
            }
        }
    }

    private func startStream() {
        streamTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.runStream()
                self.connected = false
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func runStream() async {
        let since = lastId ?? "all"
        guard let streamURL = URL(string: url("/json").absoluteString + "?since=\(since)") else { return }
        do {
            let (bytes, resp) = try await session.bytes(from: streamURL)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return }
            connected = true
            for try await line in bytes.lines {
                handle(line)
            }
        } catch {
            // reconnect loop handles it
        }
    }

    private func handle(_ line: String) {
        guard let data = line.data(using: .utf8),
              let msg = try? JSONDecoder().decode(RelayMessage.self, from: data) else { return }
        lastId = msg.id
        guard msg.event == "message", seen.insert(msg.id).inserted,
              let body = msg.message?.data(using: .utf8),
              let event = try? JSONDecoder().decode(GameEvent.self, from: body) else { return }
        state.apply(event)
        if event.type == "move" || event.type == "reset" { error = nil }
    }
}
