import SwiftUI
import AppKit

/// NSViewRepresentable wrapper around NSTextField.
/// Bypasses SwiftUI's TextField focus issues on macOS.
struct NativeTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var onSubmit: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let field = FocusTextField()
        field.placeholderString = placeholder
        field.stringValue = text

        // Appearance
        field.isBordered = false
        field.isBezeled = false
        field.backgroundColor = .clear
        field.textColor = NSColor(red: 0.87, green: 0.93, blue: 1.0, alpha: 1)   // Theme.text
        field.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: NSColor(white: 0.4, alpha: 1),
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            ]
        )
        field.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        field.focusRingType = .none
        field.isEditable = true
        field.isSelectable = true
        field.refusesFirstResponder = false

        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        // Only update if the source of truth changed externally
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    // ── Coordinator ───────────────────────────────────────────────
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NativeTextField

        init(_ parent: NativeTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl,
                     textView: NSTextView,
                     doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit?()
                return true
            }
            return false
        }
    }
}

private final class FocusTextField: NSTextField {
    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
}
