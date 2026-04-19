import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var terminal = TerminalService()
    @AppStorage("saved_ssh_command") private var savedSSHCommand: String = ""

    @State private var aiInput: String = ""
    @State private var terminalInput: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Circle()
                    .fill(terminal.isConnected ? .green : .red)
                    .frame(width: 10, height: 10)

                Text(terminal.connectionStatus)

                TextField("SSH Command...", text: $savedSSHCommand)
                    .textFieldStyle(.roundedBorder)

                Button("Connect") {
                    if !terminal.isRunning {
                        terminal.startShell()
                    }
                    terminal.connectSSH(savedSSHCommand)
                }

                Button("Disconnect") {
                    terminal.disconnectSSH()
                }

                Spacer()
            }
            .padding()

            Divider()

            HStack(spacing: 0) {
                VStack {
                    Text("Model Test")
                        .font(.headline)
                    Spacer()
                }
                .frame(width: 250)

                Divider()

                VStack(spacing: 0) {
                    TerminalTextView(terminal: terminal)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    HStack {
                        TextField("Enter command...", text: $terminalInput)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                runTerminalCommand()
                            }

                        Button("Run") {
                            runTerminalCommand()
                        }
                    }
                    .padding()
                    .background(Color(NSColor.windowBackgroundColor))
                }

                Divider()

                VStack {
                    Text("AI Trainer")
                        .font(.headline)

                    TextField("Tell AI what to do...", text: $aiInput)
                        .textFieldStyle(.roundedBorder)

                    Button("Run AI Command") {
                        runAI()
                    }

                    Spacer()
                }
                .frame(width: 300)
                .padding()
            }
        }
        .onAppear {
            terminal.startShell()
        }
    }

    private func runTerminalCommand() {
        let trimmed = terminalInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        terminal.send(trimmed)
        terminalInput = ""
    }

    private func runAI() {
        let prompt = aiInput.lowercased()

        if prompt.contains("train") && prompt.contains("polish") {
            terminal.send("cd /workspace")
            terminal.send("python train_polish_200k.py")
        } else if prompt.contains("gpu") {
            terminal.send("nvidia-smi")
        } else {
            terminal.send("echo 'AI did not understand command'")
        }

        aiInput = ""
    }
}
