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
    @Published var debugStatsOutput: String = ""

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
        resetStats()
    }

    private func resetStats() {
        gpuUsage = "--"
        gpuMemory = "-- / --"
        gpuTemp = "--°C"
        gpuPower = "--W"
        debugStatsOutput = ""
    }

    private func startStatsPolling() {
        stopStatsPolling()

        statsTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.fetchGPUStats() }
        }

        Task { await fetchGPUStats() }
    }

    private func stopStatsPolling() {
        statsTimer?.invalidate()
        statsTimer = nil
    }

    private func fetchGPUStats() async {
        guard isConnected else { return }

        guard let sshParts = parseSSHCommand(savedSSHCommand) else {
            debugStatsOutput = "Could not parse SSH command"
            return
        }

        let remoteCommand = "nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw --format=csv,noheader,nounits"

        let command = """
        ssh -T -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i \(shellEscape(sshParts.keyPath)) \(shellEscape(sshParts.target)) \(shellEscape(remoteCommand))
        """

        do {
            let output = try await runShellCommand(command)
            debugStatsOutput = output
            parseGPUStats(output)
        } catch {
            debugStatsOutput = "ERROR: \(error.localizedDescription)"
        }
    }

    private func parseSSHCommand(_ command: String) -> (target: String, keyPath: String)? {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ").map(String.init)

        guard parts.count >= 4, parts[0] == "ssh" else { return nil }

        var target: String?
        var keyPath: String?

        var i = 1
        while i < parts.count {
            let part = parts[i]

            if part == "-i", i + 1 < parts.count {
                var rawPath = parts[i + 1]
                if rawPath.hasPrefix("~/") {
                    rawPath = "/Users/user/" + rawPath.dropFirst(2)
                }
                keyPath = rawPath
                i += 2
                continue
            }

            if !part.hasPrefix("-") && target == nil {
                target = part
            }

            i += 1
        }

        guard let target, let keyPath else { return nil }
        return (target, keyPath)
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
        let lines = output
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let csvLine = lines.first(where: { $0.contains(",") }) else { return }

        let parts = csvLine
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard parts.count >= 5 else { return }

        gpuUsage = "\(parts[0])%"
        gpuMemory = "\(parts[1]) / \(parts[2]) MB"
        gpuTemp = "\(parts[3])°C"
        gpuPower = "\(parts[4])W"
    }

    private func shellEscape(_ value: String) -> String {
        if value.range(of: #"^[A-Za-z0-9_@%+=:,./-]+$"#, options: .regularExpression) != nil {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
