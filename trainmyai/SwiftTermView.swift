import SwiftUI
import AppKit
import SwiftTerm

struct SwiftTermView: NSViewRepresentable {
    @ObservedObject var terminal: TerminalService

    func makeCoordinator() -> Coordinator {
        Coordinator(terminal: terminal)
    }

    func makeNSView(context: Context) -> TerminalView {
        let view = TerminalView()
        view.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        view.nativeBackgroundColor = NSColor.black
        view.caretStyle = .underline
        view.getTerminal().delegate = context.coordinator
        context.coordinator.termView = view

        terminal.onOutput = { text in
            DispatchQueue.main.async {
                view.feed(text: text)
            }
        }

        return view
    }

    func updateNSView(_ nsView: TerminalView, context: Context) {}

    final class Coordinator: NSObject, TerminalViewDelegate {
        let terminal: TerminalService
        weak var termView: TerminalView?

        init(terminal: TerminalService) {
            self.terminal = terminal
        }

        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {}

        func setTerminalTitle(source: TerminalView, title: String) {}

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

        func requestOpenLink(source: TerminalView, link: String, params: [String : String]) {}

        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            let bytes = Array(data)
            if let text = String(bytes: bytes, encoding: .utf8) {
                terminal.sendRaw(text)
            }
        }

        func scrolled(source: TerminalView, position: Double) {}

        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
    }
}
