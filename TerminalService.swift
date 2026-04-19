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

    private var statsProcess: Process?
    private var statsPipe: Pipe?

    func connectSSH() {
        connectionStatus = "Connecting..."
    }

    func markConnected() {
        isConnected = true
        isRunning = true
        connectionStatus = "Connected"
        startHiddenStatsSession()
    }

    func disconnectSSH() {
        isConnected = false
        connectionStatus = "Disconnected"
        stopHiddenStatsSession()
        resetStats()
    }

    private func resetStats() {
        gpuUsage = "--"
        gpuMemory = "-- / --"
        gpuTemp = "--°C"
        gpuPower = "--W"
    }

    private func startHiddenStatsSession() {
        stopHiddenStatsSession()

        guard let hiddenCommand = buildHiddenStatsCommand() else { return }

        let process = Process()
        let pipe = Pipe()

        process.standardOutput = pipe
        process.standardError = pipe
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", hiddenCommand]

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let text = String(data: data, encoding: .utf8) else { return }

            Task { @MainActor in
                self?.consumeStatsOutput(text)
            }
        }

        do {
            try process.run()
            statsProcess = process
            statsPipe = pipe
        } catch {
            // silent for now
        }
    }

    private func stopHiddenStatsSession() {
        statsPipe?.fileHandleForReading.readabilityHandler = nil
        statsProcess?.terminate()
        statsProcess = nil
        statsPipe = nil
    }

    private func buildHiddenStatsCommand() -> String? {
        let trimmed = savedSSHCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("ssh ") else { return nil }

        let parts = trimmed.split(separator: " ").map(String.init)
        guard parts.count >= 4 else { return nil }

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

            if !part.hasPrefix("-"), target == nil {
                target = part
            }

            i += 1
        }

        guard let target, let keyPath else { return nil }

        let remoteLoop = """
        while true; do
          nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw --format=csv,noheader,nounits
          sleep 3
        done
        """

        return """
        ssh -tt -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i \(shellEscape(keyPath)) \(shellEscape(target)) \(shellEscape(remoteLoop))
        """
    }

    private func consumeStatsOutput(_ text: String) {
        let lines = text
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        for line in lines where line.contains(",") {
            let parts = line.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            guard parts.count >= 5 else { continue }

            gpuUsage = "\(parts[0])%"
            gpuMemory = "\(parts[1]) / \(parts[2]) MB"
            gpuTemp = "\(parts[3])°C"
            gpuPower = "\(parts[4])W"
        }
    }

    private func shellEscape(_ value: String) -> String {
        if value.range(of: #"^[A-Za-z0-9_@%+=:,./-]+$"#, options: .regularExpression) != nil {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
