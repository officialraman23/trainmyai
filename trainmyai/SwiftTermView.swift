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

        terminal.controller.attachTerminalView(view)

        NotificationCenter.default.addObserver(
            forName: .trainMyAIRunCommand,
            object: nil,
            queue: .main
        ) { note in
            if let command = note.object as? String,
               !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                terminal.controller.sendVisible(command)
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
