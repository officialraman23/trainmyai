import Foundation
import Combine

@MainActor
final class TrainingMetricsService: ObservableObject {
    @Published var loss: String = "--"
    @Published var gradNorm: String = "--"
    @Published var learningRate: String = "--"
    @Published var epoch: String = "--"
    @Published var step: String = "--"
    @Published var progress: String = "--"
    @Published var status: String = "Idle"

    func consume(_ text: String) {
        parseLoss(from: text)
        parseGradNorm(from: text)
        parseLearningRate(from: text)
        parseEpoch(from: text)
        parseStep(from: text)
        updateStatus()
    }

    private func parseLoss(from text: String) {
        if let value = firstMatch(in: text, pattern: #"loss[:= ]+([0-9]*\.?[0-9]+)"#) {
            loss = value
        }
    }

    private func parseGradNorm(from text: String) {
        if let value = firstMatch(in: text, pattern: #"grad[_ ]?norm[:= ]+([0-9]*\.?[0-9]+)"#) {
            gradNorm = value
        }
    }

    private func parseLearningRate(from text: String) {
        if let value = firstMatch(in: text, pattern: #"learning[_ ]?rate[:= ]+([0-9eE\.\-]+)"#) {
            learningRate = value
        } else if let value = firstMatch(in: text, pattern: #"lr[:= ]+([0-9eE\.\-]+)"#) {
            learningRate = value
        }
    }

    private func parseEpoch(from text: String) {
        if let value = firstMatch(in: text, pattern: #"epoch[:= ]+([0-9]*\.?[0-9]+)"#) {
            epoch = value
        }
    }

    private func parseStep(from text: String) {
        if let value = firstMatch(in: text, pattern: #"step[:= ]+([0-9]+)"#) {
            step = value
        }
    }

    private func updateStatus() {
        guard loss != "--" else {
            status = "Idle"
            return
        }

        if let grad = Double(gradNorm), grad > 10 {
            status = "Warning"
            return
        }

        status = "Stable"
    }

    private func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return String(text[valueRange])
    }
}
