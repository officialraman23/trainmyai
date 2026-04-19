import SwiftUI
import AppKit
import SwiftTerm

struct SwiftTermView: NSViewRepresentable {
    @ObservedObject var terminal: TerminalService

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let view = LocalProcessTerminalView(frame: .zero)
        view.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        view.nativeBackgroundColor = .black
        view.startProcess(executable: "/bin/zsh", args: ["-l"])

        NotificationCenter.default.addObserver(
            forName: .trainMyAIConnectSSH,
            object: nil,
            queue: .main
        ) { note in
            if let sshCommand = note.object as? String {
                view.send(txt: sshCommand)
                view.send(txt: "\n")
            }
        }

        NotificationCenter.default.addObserver(
            forName: .trainMyAIDisconnectSSH,
            object: nil,
            queue: .main
        ) { _ in
            view.send(txt: "exit\n")
        }

        NotificationCenter.default.addObserver(
            forName: .trainMyAIRunCommand,
            object: nil,
            queue: .main
        ) { note in
            if let command = note.object as? String,
               !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                view.send(txt: command)
                view.send(txt: "\n")

                // temporary parser hook for testing metrics
                terminal.consumeTrainingOutput(command)
            }
        }

        DispatchQueue.main.async {
            terminal.isRunning = true
            if !terminal.isConnected {
                terminal.connectionStatus = "Local Shell"
            }
        }

        return view
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}
}
