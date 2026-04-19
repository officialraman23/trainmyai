import Foundation
import Combine

@MainActor
final class TerminalService: ObservableObject {
    @Published var isRunning: Bool = false
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "Disconnected"
    @Published var savedSSHCommand: String = "ssh oxc74ubncdafyt-64411a83@ssh.runpod.io -i ~/.ssh/id_ed25519"

    func connectSSH() {
        connectionStatus = "Connecting..."
    }

    func markConnected() {
        isConnected = true
        isRunning = true
        connectionStatus = "Connected"
    }

    func disconnectSSH() {
        isConnected = false
        connectionStatus = "Disconnected"
    }
}
