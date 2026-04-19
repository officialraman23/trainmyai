import SwiftUI
import AppKit

struct TerminalTextView: NSViewRepresentable {
    @ObservedObject var terminal: TerminalService

    func makeCoordinator() -> Coordinator {
        Coordinator(terminal: terminal)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .black

        let textView = TerminalNSTextView()
        textView.coordinator = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = false
        textView.backgroundColor = .black
        textView.textColor = .systemGreen
        textView.insertionPointColor = .systemGreen
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.string = terminal.output

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.lastRenderedText = terminal.output

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }

        let newText = terminal.output
        let oldText = context.coordinator.lastRenderedText

        guard newText != oldText else { return }

        if newText.hasPrefix(oldText) {
            let appended = String(newText.dropFirst(oldText.count))
            if !appended.isEmpty {
                let attr = NSAttributedString(
                    string: appended,
                    attributes: [
                        .foregroundColor: NSColor.systemGreen,
                        .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
                    ]
                )
                textView.textStorage?.append(attr)
                textView.scrollToEndOfDocument(nil)
            }
        } else {
            textView.string = newText
            textView.scrollToEndOfDocument(nil)
        }

        context.coordinator.lastRenderedText = newText
    }

    final class Coordinator: NSObject {
        let terminal: TerminalService
        weak var textView: TerminalNSTextView?
        var lastRenderedText: String = ""

        init(terminal: TerminalService) {
            self.terminal = terminal
        }

        func handleUserInput(_ input: String) {
            terminal.sendRaw(input)
        }
    }
}

final class TerminalNSTextView: NSTextView {
    weak var coordinator: TerminalTextView.Coordinator?

    override func keyDown(with event: NSEvent) {
        guard let coordinator else {
            super.keyDown(with: event)
            return
        }

        if let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
            coordinator.handleUserInput(chars)
        } else {
            super.keyDown(with: event)
        }
    }

    override func insertNewline(_ sender: Any?) {
        coordinator?.handleUserInput("\n")
    }

    override func insertTab(_ sender: Any?) {
        coordinator?.handleUserInput("\t")
    }

    override func deleteBackward(_ sender: Any?) {
        coordinator?.handleUserInput("\u{7F}")
    }

    override func moveLeft(_ sender: Any?) {
        coordinator?.handleUserInput("\u{1B}[D")
    }

    override func moveRight(_ sender: Any?) {
        coordinator?.handleUserInput("\u{1B}[C")
    }

    override func moveUp(_ sender: Any?) {
        coordinator?.handleUserInput("\u{1B}[A")
    }

    override func moveDown(_ sender: Any?) {
        coordinator?.handleUserInput("\u{1B}[B")
    }
}
