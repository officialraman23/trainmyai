import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var terminal = TerminalService()
    @AppStorage("saved_ssh_command") private var savedSSHCommand: String = ""
    @State private var command: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Circle()
                    .fill(terminal.isConnected ? .green : .red)
                    .frame(width: 10, height: 10)

                Text(terminal.connectionStatus)
                    .font(.headline)

                TextField("Paste RunPod SSH command...", text: $savedSSHCommand)
                    .textFieldStyle(.roundedBorder)

                Button("Connect") {
                    if !terminal.isRunning {
                        terminal.startShell()
                    }
                    terminal.connectSSH(savedSSHCommand)
                }
                .disabled(savedSSHCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Disconnect") {
                    terminal.disconnectSSH()
                }
                .disabled(!terminal.isConnected)

                Button(terminal.isRunning ? "Stop Shell" : "Start Shell") {
                    if terminal.isRunning {
                        terminal.stopShell()
                    } else {
                        terminal.startShell()
                    }
                }

                Spacer()
            }
            .padding()

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    Text(terminal.output)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                        .font(.system(.body, design: .monospaced))
                        .id("BOTTOM")
                }
                .background(Color.black.opacity(0.92))
                .foregroundColor(.green)
                .onChange(of: terminal.output) { _, _ in
                    proxy.scrollTo("BOTTOM", anchor: .bottom)
                }
            }

            Divider()

            HStack {
                TextField("Enter command...", text: $command)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        runCommand()
                    }

                Button("Run") {
                    runCommand()
                }
                .disabled(!terminal.isRunning || command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 1200, minHeight: 700)
        .onAppear {
            terminal.startShell()
        }
    }

    private func runCommand() {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        terminal.send(trimmed)
        command = ""
    }
}
