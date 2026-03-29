import SwiftUI
import AppKit

/// Invisible NSView embedded in the SwiftUI hierarchy.
/// - On attach: makes the window key immediately.
/// - Installs a local event monitor so every left-click inside
///   the window re-claims key status, keeping keyboard input
///   inside the app instead of leaking to another app.
struct WindowKeyFix: NSViewRepresentable {
    func makeNSView(context: Context) -> _KeyFixView { _KeyFixView() }
    func updateNSView(_ nsView: _KeyFixView, context: Context) {}
}

final class _KeyFixView: NSView {
    private var localMonitor: Any?
    private var globalMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }

        // Activate immediately
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Local monitor handles clicks after the app is already active.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak window] event in
            if let window {
                self.activate(window)
            }
            return event
        }

        // Global monitor handles the first click when another app is active.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak window] _ in
            guard let window else { return }
            let mouseLocation = NSEvent.mouseLocation
            guard window.frame.contains(mouseLocation) else { return }
            DispatchQueue.main.async {
                self.activate(window)
            }
        }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            if let localMonitor {
                NSEvent.removeMonitor(localMonitor)
                self.localMonitor = nil
            }
            if let globalMonitor {
                NSEvent.removeMonitor(globalMonitor)
                self.globalMonitor = nil
            }
        }
    }

    private func activate(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}
