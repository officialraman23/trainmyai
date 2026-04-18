import Foundation
import Combine

@MainActor
final class TerminalService: ObservableObject {
    @Published var output: String = ""
    @Published var isRunning: Bool = false
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "Disconnected"

    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?

    func startShell() {
        guard process == nil else { return }

        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()

        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l"]

        let handle = outputPipe.fileHandleForReading
        handle.readabilityHandler = { [weak self] fileHandle in
            let data = fileHandle.availableData
            guard !data.isEmpty,
                  let text = String(data: data, encoding: .utf8) else { return }

            Task { @MainActor in
                let cleaned = self?.cleanTerminalText(text) ?? text
                self?.output += cleaned

                if cleaned.contains("root@"), cleaned.contains(":/") || cleaned.contains(":#") {
                    self?.isConnected = true
                    self?.connectionStatus = "Connected"
                }

                if cleaned.lowercased().contains("connection closed")
                    || cleaned.lowercased().contains("could not resolve hostname")
                    || cleaned.lowercased().contains("permission denied")
                    || cleaned.lowercased().contains("connection refused") {
                    self?.isConnected = false
                    self?.connectionStatus = "Disconnected"
                }
            }
        }

        do {
            try process.run()
            self.process = process
            self.inputPipe = inputPipe
            self.outputPipe = outputPipe
            self.isRunning = true
        } catch {
            self.output += "\n[ERROR] Failed to start shell: \(error.localizedDescription)\n"
        }
    }

    func send(_ command: String) {
        guard let inputPipe else {
            output += "\n[ERROR] Shell is not running.\n"
            return
        }

        let fullCommand = command + "\n"
        if let data = fullCommand.data(using: .utf8) {
            inputPipe.fileHandleForWriting.write(data)
        }
    }

    func connectSSH(_ sshCommand: String) {
        connectionStatus = "Connecting..."
        send(sshCommand)
    }

    func disconnectSSH() {
        send("exit")
        isConnected = false
        connectionStatus = "Disconnected"
    }

    func stopShell() {
        inputPipe?.fileHandleForWriting.write(Data("exit\n".utf8))
        process?.terminate()
        process = nil
        inputPipe = nil
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil
        isRunning = false
        isConnected = false
        connectionStatus = "Disconnected"
    }

    private func cleanTerminalText(_ text: String) -> String {
        var cleaned = text

        let patterns = [
            #"\u{001B}\[[0-9;?]*[A-Za-z]"#,   // ANSI escape codes
            #"\u{001B}\].*?\u{0007}"#,        // OSC title sequences
            #"\r"#                            // carriage returns
        ]

        for pattern in patterns {
            cleaned = cleaned.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }

        return cleaned
    }

    deinit {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
    }
}
