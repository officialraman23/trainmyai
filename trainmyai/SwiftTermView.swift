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
        DispatchQueue.main.async {
            terminal.isRunning = true
        }
        return view
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}
}
