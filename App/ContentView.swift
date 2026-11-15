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
            logo
            VStack(spacing: 6) {
                Text("Tic Tac Toe")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("Play online with a friend")
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Button {
                model.create()
            } label: {
                Text("Create Game")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Theme.pink.opacity(0.45), radius: 16, y: 8)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)

            HStack(spacing: 12) {
                Rectangle().frame(height: 1).foregroundStyle(.white.opacity(0.2))
                Text("or join").font(.footnote.weight(.medium)).foregroundStyle(.white.opacity(0.6))
                Rectangle().frame(height: 1).foregroundStyle(.white.opacity(0.2))
            }

            joinRow

            if let error = model.error {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(Color(red: 1.0, green: 0.6, blue: 0.65))
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(24)
        .background(GradientBackground())
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var logo: some View {
        Image(systemName: "number.square.fill")
            .font(.system(size: 76))
            .foregroundStyle(.white)
            .frame(width: 128, height: 128)
            .background(Theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .shadow(color: Theme.blue.opacity(0.5), radius: 24, y: 10)
    }

    private var joinRow: some View {
        HStack(spacing: 12) {
            TextField("Room code", text: $code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(.title3, design: .monospaced, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )
                .onSubmit { model.join(code: code) }
            Button {
                model.join(code: code)
            } label: {
                Text("Join")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .frame(height: 56)
                    .background(Color.white.opacity(isCodeValid ? 0.25 : 0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!isCodeValid)
        }
    }

    private var isCodeValid: Bool {
        code.trimmingCharacters(in: .whitespaces).count == 6
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
