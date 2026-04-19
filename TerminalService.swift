import Foundation
import Combine

@MainActor
final class TerminalService: ObservableObject {
    @Published var isRunning: Bool = false
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "Disconnected"
    @Published var savedSSHCommand: String = "ssh oxc74ubncdafyt-64411a83@ssh.runpod.io -i ~/.ssh/id_ed25519"

    let hiddenStats = HiddenStatsService()

    var gpuUsage: String { hiddenStats.gpuUsage }
    var gpuMemory: String { hiddenStats.gpuMemory }
    var gpuTemp: String { hiddenStats.gpuTemp }
    var gpuPower: String { hiddenStats.gpuPower }

    func connectSSH() {
        connectionStatus = "Connecting..."
    }

    func markConnected() {
        isConnected = true
        isRunning = true
        connectionStatus = "Connected"
        hiddenStats.start(using: savedSSHCommand)
    }

    func disconnectSSH() {
        isConnected = false
        connectionStatus = "Disconnected"
        hiddenStats.stop()
    }
}
