import SwiftUI

struct ContentView: View {
    @StateObject private var terminal = TerminalService()
    @AppStorage("saved_ssh_command") private var savedSSHCommand: String = ""
    @State private var aiInput: String = ""

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
                    terminal.connectSSH()
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

                SwiftTermView(terminal: terminal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                VStack {
                    Text("AI Trainer")
                        .font(.headline)

                    TextField("Tell AI what to do...", text: $aiInput)
                        .textFieldStyle(.roundedBorder)

                    Button("Run AI Command") {
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
