import Foundation
import Combine

@MainActor
final class TerminalService: ObservableObject {
    @Published var isRunning: Bool = false
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "Disconnected"
    @Published var savedSSHCommand: String = "ssh oxc74ubncdafyt-64411a83@ssh.runpod.io -i ~/.ssh/id_ed25519"

    @Published var loss: String = "--"
    @Published var gradNorm: String = "--"
    @Published var learningRate: String = "--"
    @Published var epoch: String = "--"
    @Published var step: String = "--"
    @Published var progress: String = "--"
    @Published var trainingStatus: String = "Idle"

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
        resetTrainingMetrics()
    }

    func updateTrainingMetrics(
        loss: String? = nil,
        gradNorm: String? = nil,
        learningRate: String? = nil,
        epoch: String? = nil,
        step: String? = nil,
        progress: String? = nil
    ) {
        if let loss { self.loss = loss }
        if let gradNorm { self.gradNorm = gradNorm }
        if let learningRate { self.learningRate = learningRate }
        if let epoch { self.epoch = epoch }
        if let step { self.step = step }
        if let progress { self.progress = progress }

        updateTrainingStatus()
    }

    private func updateTrainingStatus() {
        if loss == "--" {
            trainingStatus = "Idle"
            return
        }

        if let grad = Double(gradNorm), grad > 10 {
            trainingStatus = "Warning"
            return
        }

        trainingStatus = "Stable"
    }

    private func resetTrainingMetrics() {
        loss = "--"
        gradNorm = "--"
        learningRate = "--"
        epoch = "--"
        step = "--"
        progress = "--"
        trainingStatus = "Idle"
    }
}
