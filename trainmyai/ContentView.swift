import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var terminal = TerminalService()
    @AppStorage("saved_ssh_command") private var savedSSHCommand: String = ""

    @State private var command: String = ""
    @State private var aiInput: String = ""

    var body: some View {
        VStack(spacing: 0) {

            // TOP BAR
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

                // LEFT PANEL (future model chat)
                VStack {
                    Text("Model Test")
                        .font(.headline)
                    Spacer()
                }
                .frame(width: 250)

                Divider()

                // CENTER TERMINAL
                VStack {
                    ScrollViewReader { proxy in
                        ScrollView {
                            Text(terminal.output)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .id("BOTTOM")
                        }
                        .background(Color.black)
                        .foregroundColor(.green)
                        .onChange(of: terminal.output) { _, _ in
                            proxy.scrollTo("BOTTOM", anchor: .bottom)
                        }
                    }

                    HStack {
                        TextField("Enter command...", text: $command)
                            .onSubmit { runCommand() }

                        Button("Run") {
                            runCommand()
                        }
                    }
                    .padding()
                }

                Divider()

                // RIGHT PANEL (AI TRAINER)
                VStack {
                    Text("AI Trainer")
                        .font(.headline)

                    TextField("Tell AI what to do...", text: $aiInput)

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

    private func runCommand() {
        guard !command.isEmpty else { return }
        terminal.send(command)
        command = ""
    }

    private func runAI() {
        let prompt = aiInput.lowercased()

        if prompt.contains("train") && prompt.contains("polish") {
            terminal.send("cd /workspace")
            terminal.send("python train_polish_200k.py")
        }
        else if prompt.contains("gpu") {
            terminal.send("nvidia-smi")
        }
        else {
            terminal.send("echo 'AI did not understand command'")
        }

        aiInput = ""
    }
}
