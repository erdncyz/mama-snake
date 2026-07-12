import SwiftUI

struct MultiplayerLobbyView: View {
    @ObservedObject private var multiplayerService = MultiplayerService.shared
    @Environment(\.dismiss) private var dismiss

    let nickname: String
    let onGameReady: () -> Void

    @State private var joinCode = ""
    @State private var didStartGame = false

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.07, blue: 0.09)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ONLINE CO-OP")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text("Two bugs, one shared garden")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.55))
                    }
                    Spacer()
                    Button(action: closeLobby) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .accessibilityLabel("Close")
                }

                Spacer()

                switch multiplayerService.status {
                case .creating, .joining:
                    ProgressView()
                        .controlSize(.large)
                        .tint(.green)
                    Text(multiplayerService.status == .creating ? "Creating room..." : "Joining room...")
                        .foregroundColor(.white.opacity(0.7))

                case .waiting:
                    waitingContent

                case .playing:
                    ProgressView("Starting game...")
                        .tint(.green)
                        .foregroundColor(.white)

                default:
                    roomActions
                }

                if let errorMessage = multiplayerService.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 10, height: 10)
                    Text(nickname)
                    Text("+")
                        .foregroundColor(.white.opacity(0.4))
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 10, height: 10)
                    Text(multiplayerService.opponentNickname.isEmpty ? "Player 2" : multiplayerService.opponentNickname)
                }
                .font(.footnote.weight(.semibold))
                .foregroundColor(.white.opacity(0.75))
            }
            .padding(28)
        }
        .onChange(of: multiplayerService.status) { _, newStatus in
            if newStatus == .playing {
                startGame()
            }
        }
        .onAppear {
            if multiplayerService.status == .playing {
                startGame()
            }
        }
        .interactiveDismissDisabled(
            multiplayerService.status != .idle || multiplayerService.role != nil)
        .onDisappear {
            guard !didStartGame, multiplayerService.role != nil else { return }
            Task {
                await multiplayerService.leaveRoom()
            }
        }
    }

    private var roomActions: some View {
        VStack(spacing: 22) {
            Button {
                Task {
                    await multiplayerService.createRoom(nickname: nickname)
                }
            } label: {
                Label("CREATE ROOM", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .foregroundColor(.black)
                    .background(Color.green)
                    .cornerRadius(8)
            }

            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 1)
                Text("OR JOIN")
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.45))
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 1)
            }

            TextField("ROOM CODE", text: $joinCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .multilineTextAlignment(.center)
                .font(.system(size: 25, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1))
                .cornerRadius(8)
                .onChange(of: joinCode) { _, value in
                    joinCode = String(value.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(6))
                }

            Button {
                Task {
                    await multiplayerService.joinRoom(code: joinCode, nickname: nickname)
                }
            } label: {
                Label("JOIN ROOM", systemImage: "arrow.right.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .foregroundColor(.white)
                    .background(joinCode.count == 6 ? Color.orange : Color.gray.opacity(0.35))
                    .cornerRadius(8)
            }
            .disabled(joinCode.count != 6)
        }
    }

    private var waitingContent: some View {
        VStack(spacing: 18) {
            Text("SHARE THIS CODE")
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.55))
            Text(multiplayerService.roomCode)
                .font(.system(size: 44, weight: .heavy, design: .monospaced))
                .foregroundColor(.yellow)

            ShareLink(item: multiplayerService.roomCode) {
                Label("SHARE CODE", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 22)
                    .frame(height: 48)
                    .background(Color.yellow)
                    .cornerRadius(8)
            }

            ProgressView()
                .tint(.green)
                .padding(.top, 12)
            Text("Waiting for the second player")
                .foregroundColor(.white.opacity(0.65))
        }
    }

    private func startGame() {
        guard !didStartGame else { return }
        didStartGame = true
        dismiss()
        onGameReady()
    }

    private func closeLobby() {
        Task {
            await multiplayerService.leaveRoom()
            dismiss()
        }
    }
}