import SwiftUI
import AppKit

@main
struct FocusQuestApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

// ── App Delegate ──────────────────────────────────────────────────
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.appearance = NSAppearance(named: .darkAqua)

        DispatchQueue.main.async {
            guard let window = NSApp.windows.first else { return }
            self.styleWindow(window)
        }
    }

    private func styleWindow(_ window: NSWindow) {
        window.level = .normal
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = false
        window.backgroundColor = NSColor(red: 0.027, green: 0.051, blue: 0.102, alpha: 1)

        window.minSize = NSSize(width: 520, height: 400)

        if window.frame.width < 540 {
            window.setContentSize(NSSize(width: 560, height: 700))
            window.center()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
