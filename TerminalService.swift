import Foundation
import Combine

@MainActor
final class TerminalService: ObservableObject {
    @Published var isRunning: Bool = false
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "Disconnected"
    @Published var savedSSHCommand: String = "ssh oxc74ubncdafyt-64411a83@ssh.runpod.io -i ~/.ssh/id_ed25519"

    let metrics = TrainingMetricsService()

    var loss: String { metrics.loss }
    var gradNorm: String { metrics.gradNorm }
    var learningRate: String { metrics.learningRate }
    var epoch: String { metrics.epoch }
    var step: String { metrics.step }
    var progress: String { metrics.progress }
    var trainingStatus: String { metrics.status }

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

    func consumeTrainingOutput(_ text: String) {
        metrics.consume(text)
        objectWillChange.send()
    }
}
