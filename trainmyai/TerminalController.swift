import Foundation
import SwiftUI

@MainActor
final class TerminalController: ObservableObject {
    weak var terminalView: LocalProcessTerminalView?

    @Published var isSSHConnected: Bool = false

    private var statsTimer: Timer?
    private var isCapturingStatsBlock = false
    private var statsBuffer = ""

    var onStatsParsed: ((String, String, String, String) -> Void)?
    var onConnectionChanged: ((Bool) -> Void)?

    func attachTerminalView(_ view: LocalProcessTerminalView) {
        terminalView = view
    }

    func connectSSH(command: String) {
        sendVisible(command)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isSSHConnected = true
            self.onConnectionChanged?(true)
        }
    }

    func disconnectSSH() {
        stopStatsPolling()
        sendVisible("exit")
        isSSHConnected = false
        onConnectionChanged?(false)
    }

    func sendVisible(_ command: String) {
        terminalView?.send(txt: command)
        terminalView?.send(txt: "\n")
    }

    func startStatsWatcher() {
        let watcher = """
        mkdir -p /tmp/trainmyai && nohup bash -c 'while true; do nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw --format=csv,noheader,nounits > /tmp/trainmyai/gpu_stats.txt; sleep 3; done' >/tmp/trainmyai/gpu_watcher.log 2>&1 &
        """
        sendVisible(watcher)
        startStatsPolling()
    }

    func startStatsPolling() {
        stopStatsPolling()

        statsTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            guard let self, self.isSSHConnected else { return }
            self.requestStatsRead()
        }

        requestStatsRead()
    }

    func stopStatsPolling() {
        statsTimer?.invalidate()
        statsTimer = nil
    }

    private func requestStatsRead() {
        guard let terminalView else { return }

        isCapturingStatsBlock = true
        statsBuffer = ""

        terminalView.send(txt: "echo __TRAINMYAI_STATS_START__\n")
        terminalView.send(txt: "cat /tmp/trainmyai/gpu_stats.txt 2>/dev/null\n")
        terminalView.send(txt: "echo __TRAINMYAI_STATS_END__\n")
    }

    func consumeTerminalOutput(_ text: String) {
        guard isCapturingStatsBlock else { return }

        statsBuffer += text

        guard statsBuffer.contains("__TRAINMYAI_STATS_START__"),
              statsBuffer.contains("__TRAINMYAI_STATS_END__") else {
            return
        }

        let parts = statsBuffer.components(separatedBy: "__TRAINMYAI_STATS_START__")
        guard let afterStart = parts.last else {
            isCapturingStatsBlock = false
            statsBuffer = ""
            return
        }

        let endParts = afterStart.components(separatedBy: "__TRAINMYAI_STATS_END__")
        guard let statsBody = endParts.first else {
            isCapturingStatsBlock = false
            statsBuffer = ""
            return
        }

        parseStats(statsBody)

        isCapturingStatsBlock = false
        statsBuffer = ""
    }

    private func parseStats(_ raw: String) {
        let lines = raw
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.contains(",") }

        guard let csvLine = lines.last else { return }

        let parts = csvLine
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard parts.count >= 5 else { return }

        let gpu = "\(parts[0])%"
        let memory = "\(parts[1]) / \(parts[2]) MB"
        let temp = "\(parts[3])°C"
        let power = "\(parts[4])W"

        onStatsParsed?(gpu, memory, temp, power)
    }
}
