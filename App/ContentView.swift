import SwiftUI

struct ContentView: View {
    @State private var model = GameModel()

    var body: some View {
        NavigationStack {
            Group {
                if model.inRoom {
                    GameView(model: model)
                } else {
                    LobbyView(model: model)
                }
            }
            .navigationTitle("Tic Tac Toe")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct LobbyView: View {
    let model: GameModel
    @State private var code = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "number.square.fill")
                .font(.system(size: 80))
                .foregroundStyle(.tint)
            Text("Play online with a friend")
                .font(.title3)

            Button {
                model.create()
            } label: {
                Text("Create Game").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            HStack {
                Rectangle().frame(height: 1).foregroundStyle(.quaternary)
                Text("or").foregroundStyle(.secondary)
                Rectangle().frame(height: 1).foregroundStyle(.quaternary)
            }

            HStack {
                TextField("Room code", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .font(.title3.monospaced())
                    .onSubmit { model.join(code: code) }
                Button("Join") { model.join(code: code) }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(code.trimmingCharacters(in: .whitespaces).count != 6)
            }

            if let error = model.error {
                Text(error).foregroundStyle(.red).font(.callout)
            }
            Spacer()
        }
        .padding(24)
    }
}

struct GameView: View {
    let model: GameModel

    private var status: String {
        let s = model.state
        if s.players.count < 2 { return "Waiting for opponent…" }
        if let w = s.winner { return w == model.myMark ? "You win! 🎉" : "You lose" }
        if s.isDraw { return "Draw" }
        return s.turn == model.myMark ? "Your turn" : "Opponent's turn"
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                HStack {
                    Text("Room").foregroundStyle(.secondary)
                    Text(model.roomCode).font(.title2.monospaced().bold())
                    ShareLink(item: "Join my Tic Tac Toe game with code \(model.roomCode)") {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                HStack(spacing: 6) {
                    Circle().fill(model.connected ? .green : .orange).frame(width: 8, height: 8)
                    Text(model.connected ? "Connected" : "Connecting…")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if let me = model.myMark {
                HStack(spacing: 32) {
                    score("You (\(me.rawValue))", me == .x ? model.state.scoreX : model.state.scoreO)
                    score("Opponent", me == .x ? model.state.scoreO : model.state.scoreX)
                }
            } else {
                Text("Joining…").foregroundStyle(.secondary)
            }

            Text(status).font(.title2.bold())

            Board(model: model)
                .aspectRatio(1, contentMode: .fit)

            if model.state.isOver {
                Button("Play Again") { model.rematch() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }

            if let error = model.error {
                Text(error).foregroundStyle(.red).font(.callout)
            }

            Spacer()

            Button("Leave Game", role: .destructive) { model.leave() }
        }
        .padding()
    }

    private func score(_ title: String, _ value: Int) -> some View {
        VStack {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text("\(value)").font(.title.bold())
        }
    }
}

struct Board: View {
    let model: GameModel

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 8
            let side = (geo.size.width - spacing * 2) / 3
            VStack(spacing: spacing) {
                ForEach(0..<3, id: \.self) { r in
                    HStack(spacing: spacing) {
                        ForEach(0..<3, id: \.self) { c in
                            cell(r * 3 + c, side: side)
                        }
                    }
                }
            }
        }
    }

    private func cell(_ i: Int, side: CGFloat) -> some View {
        let mark = model.state.board[i]
        let winning = model.state.winLine.contains(i)
        return Button {
            model.play(i)
        } label: {
            Text(mark?.rawValue ?? "")
                .font(.system(size: side * 0.6, weight: .heavy, design: .rounded))
                .foregroundStyle(mark == .x ? Color.blue : Color.pink)
                .frame(width: side, height: side)
                .background(winning ? Color.green.opacity(0.35) : Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!model.canPlay || mark != nil)
    }
}
