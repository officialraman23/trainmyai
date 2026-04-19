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

                if cleaned.contains("root@") && (cleaned.contains(":/") || cleaned.contains(":#")) {
                    self?.isConnected = true
                    self?.connectionStatus = "Connected"
                }

                let lower = cleaned.lowercased()
                if lower.contains("connection closed")
                    || lower.contains("could not resolve hostname")
                    || lower.contains("permission denied")
                    || lower.contains("connection refused")
                    || lower.contains("broken pipe") {
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
        sendRaw(command + "\n")
    }

    func sendRaw(_ raw: String) {
        guard let inputPipe else {
            output += "\n[ERROR] Shell is not running.\n"
            return
        }

        if let data = raw.data(using: .utf8) {
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
            #"\u{001B}\].*?\u{0007}"#,
            #"\r"#
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
