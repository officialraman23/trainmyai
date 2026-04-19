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

    let controller = TerminalController()

    init() {
        controller.onConnectionChanged = { [weak self] connected in
            guard let self else { return }
            self.isConnected = connected
            self.isRunning = connected
            self.connectionStatus = connected ? "Connected" : "Disconnected"
            if !connected {
                self.resetStats()
            }
        }

        controller.onStatsParsed = { [weak self] gpu, memory, temp, power in
            guard let self else { return }
            self.gpuUsage = gpu
            self.gpuMemory = memory
            self.gpuTemp = temp
            self.gpuPower = power
        }
    }

    func connectSSH() {
        connectionStatus = "Connecting..."
        controller.connectSSH(command: savedSSHCommand)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.controller.startStatsWatcher()
        }
    }

    func disconnectSSH() {
        controller.disconnectSSH()
    }

    private func resetStats() {
        gpuUsage = "--"
        gpuMemory = "-- / --"
        gpuTemp = "--°C"
        gpuPower = "--W"
    }
}
