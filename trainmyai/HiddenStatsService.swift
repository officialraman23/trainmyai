import Foundation
import Combine

@MainActor
final class HiddenStatsService: ObservableObject {
    @Published var gpuUsage: String = "--"
    @Published var gpuMemory: String = "-- / --"
    @Published var gpuTemp: String = "--°C"
    @Published var gpuPower: String = "--W"

    private var statsProcess: Process?
    private var statsPipe: Pipe?

    func start(using sshCommand: String) {
        stop()

        guard let command = buildHiddenStatsCommand(from: sshCommand) else { return }

        let process = Process()
        let pipe = Pipe()

        process.standardOutput = pipe
        process.standardError = pipe
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let text = String(data: data, encoding: .utf8) else { return }

            Task { @MainActor in
                self?.consume(text)
            }
        }

        do {
            try process.run()
            statsProcess = process
            statsPipe = pipe
        } catch {
            reset()
        }
    }

    func stop() {
        statsPipe?.fileHandleForReading.readabilityHandler = nil
        statsProcess?.terminate()
        statsProcess = nil
        statsPipe = nil
        reset()
    }

    private func reset() {
        gpuUsage = "--"
        gpuMemory = "-- / --"
        gpuTemp = "--°C"
        gpuPower = "--W"
    }

    private func consume(_ text: String) {
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

    private func buildHiddenStatsCommand(from sshCommand: String) -> String? {
        let trimmed = sshCommand.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func shellEscape(_ value: String) -> String {
        if value.range(of: #"^[A-Za-z0-9_@%+=:,./-]+$"#, options: .regularExpression) != nil {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
