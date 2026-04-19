import SwiftUI
import AppKit

struct TerminalTextView: NSViewRepresentable {
    @ObservedObject var terminal: TerminalService

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .black

        let textView = NSTextView()
        textView.isEditable = false
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
        weak var textView: NSTextView?
        var lastRenderedText: String = ""
    }
}
