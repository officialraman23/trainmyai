import Foundation
import Combine

@MainActor
final class TerminalService: ObservableObject {
    @Published var isRunning: Bool = false
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "Disconnected"
    @Published var savedSSHCommand: String = "ssh oxc74ubncdafyt-64411a83@ssh.runpod.io -i ~/.ssh/id_ed25519"

    @Published var gpuUsage: String = "--"
    @Published var gpuMemory: String = "-- / --"
    @Published var gpuTemp: String = "--°C"
    @Published var gpuPower: String = "--W"

    private var statsTimer: Timer?

    func connectSSH() {
        connectionStatus = "Connecting..."
    }

    func markConnected() {
        isConnected = true
        isRunning = true
        connectionStatus = "Connected"
        startStatsPolling()
    }

    func disconnectSSH() {
        isConnected = false
        connectionStatus = "Disconnected"
        stopStatsPolling()
        gpuUsage = "--"
        gpuMemory = "-- / --"
        gpuTemp = "--°C"
        gpuPower = "--W"
    }

    private func startStatsPolling() {
        stopStatsPolling()

        statsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.fetchGPUStats()
            }
        }

        Task { @MainActor in
            await fetchGPUStats()
        }
    }

    private func stopStatsPolling() {
        statsTimer?.invalidate()
        statsTimer = nil
    }

    private func fetchGPUStats() async {
        guard isConnected else { return }

        let remoteCommand = #"nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw --format=csv,noheader,nounits"#
        let fullCommand = buildHiddenSSHCommand(remoteCommand: remoteCommand)

        guard !fullCommand.isEmpty else { return }

        do {
            let output = try await runShellCommand(fullCommand)
            parseGPUStats(output)
        } catch {
            // Keep UI stable, don't spam errors in visible terminal
        }
    }

    private func buildHiddenSSHCommand(remoteCommand: String) -> String {
        let trimmed = savedSSHCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if trimmed.hasPrefix("ssh ") {
            let withoutSSH = String(trimmed.dropFirst(4))
            return "ssh -o BatchMode=yes \(withoutSSH) \"\(remoteCommand)\""
        }

        return ""
    }

    private func runShellCommand(_ command: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let pipe = Pipe()

            process.standardOutput = pipe
            process.standardError = pipe
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", command]

            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: output)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func parseGPUStats(_ output: String) {
        let firstLine = output
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && $0.contains(",") }

        guard let line = firstLine else { return }

        let parts = line.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard parts.count >= 5 else { return }

        gpuUsage = "\(parts[0])%"
        gpuMemory = "\(parts[1]) / \(parts[2]) MB"
        gpuTemp = "\(parts[3])°C"
        gpuPower = "\(parts[4])W"
    }
}
