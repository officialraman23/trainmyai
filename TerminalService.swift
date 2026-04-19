import Foundation
import Combine

@MainActor
final class TerminalService: ObservableObject {
    @Published var isRunning: Bool = false
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "Disconnected"

    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?

    var onOutput: ((String) -> Void)?

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
                self?.handleIncomingText(text)
            }
        }

        do {
            try process.run()
            self.process = process
            self.inputPipe = inputPipe
            self.outputPipe = outputPipe
            self.isRunning = true
        } catch {
            onOutput?("\r\n[ERROR] Failed to start shell: \(error.localizedDescription)\r\n")
        }
    }

    func send(_ command: String) {
        sendRaw(command + "\n")
    }

    func sendRaw(_ raw: String) {
        guard let inputPipe else { return }
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

    private func handleIncomingText(_ text: String) {
        if text.contains("root@") && (text.contains(":/") || text.contains(":#")) {
            isConnected = true
            connectionStatus = "Connected"
        }

        let lower = text.lowercased()
        if lower.contains("connection closed")
            || lower.contains("could not resolve hostname")
            || lower.contains("permission denied")
            || lower.contains("connection refused")
            || lower.contains("broken pipe") {
            isConnected = false
            connectionStatus = "Disconnected"
        }

        onOutput?(text)
    }

    deinit {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
    }
}
