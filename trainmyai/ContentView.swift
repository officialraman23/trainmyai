import SwiftUI

struct ContentView: View {
    @StateObject private var terminal = TerminalService()
    @State private var aiInput: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Circle()
                    .fill(terminal.isConnected ? .green : .red)
                    .frame(width: 10, height: 10)

                Text(terminal.connectionStatus)

                TextField("SSH Command...", text: $terminal.savedSSHCommand)
                    .textFieldStyle(.roundedBorder)

                Button("Connect") {
                    terminal.connectSSH()

                    NotificationCenter.default.post(
                        name: .trainMyAIConnectSSH,
                        object: terminal.savedSSHCommand
                    )

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        terminal.markConnected()
                    }
                }

                Button("Disconnect") {
                    terminal.disconnectSSH()

                    NotificationCenter.default.post(
                        name: .trainMyAIDisconnectSSH,
                        object: nil
                    )
                }

                Spacer()
            }
            .padding()

            Divider()

            HStack(spacing: 18) {
                MetricCard(title: "Loss", value: terminal.loss)
                MetricCard(title: "Grad Norm", value: terminal.gradNorm)
                MetricCard(title: "LR", value: terminal.learningRate)
                MetricCard(title: "Epoch", value: terminal.epoch)
                MetricCard(title: "Step", value: terminal.step)
                MetricCard(title: "Progress", value: terminal.progress)
                MetricCard(title: "Status", value: terminal.trainingStatus)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider()

            HStack(spacing: 0) {
                VStack {
                    Text("Model Test")
                        .font(.headline)
                    Spacer()
                }
                .frame(width: 250)

                Divider()

                SwiftTermView(terminal: terminal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                VStack {
                    Text("AI Trainer")
                        .font(.headline)

                    TextField("Tell AI what to do...", text: $aiInput)
                        .textFieldStyle(.roundedBorder)

                    Button("Run AI Command") {
                        if !aiInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            NotificationCenter.default.post(
                                name: .trainMyAIRunCommand,
                                object: aiInput
                            )
                        }
                        aiInput = ""
                    }

                    Spacer()
                }
                .frame(width: 300)
                .padding()
            }
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

extension Notification.Name {
    static let trainMyAIConnectSSH = Notification.Name("trainMyAIConnectSSH")
    static let trainMyAIDisconnectSSH = Notification.Name("trainMyAIDisconnectSSH")
    static let trainMyAIRunCommand = Notification.Name("trainMyAIRunCommand")
}
