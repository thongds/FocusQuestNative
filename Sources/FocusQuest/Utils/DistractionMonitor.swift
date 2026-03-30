import Foundation
import AppKit
import ApplicationServices

/// Monitors the frontmost browser's URL and fires callbacks when a blocked
/// domain is detected or cleared.  Must be used on the main thread.
final class DistractionMonitor {

    var onDistracted: ((String) -> Void)?
    var onCleared: (() -> Void)?

    private var blockedURLs: [String] = []
    private var pollTimer: Timer?
    private var currentlyDistracted = false

    // ── Public API ────────────────────────────────────────────────

    func start(blockedURLs: [String]) {
        stop()
        self.blockedURLs = blockedURLs
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeAppChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        checkFrontmostApp()
    }

    func stop() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        pollTimer?.invalidate()
        pollTimer = nil
        currentlyDistracted = false
    }

    func updateBlockedURLs(_ urls: [String]) {
        blockedURLs = urls
        checkFrontmostApp()
    }

    // ── Permission ────────────────────────────────────────────────

    static var hasPermission: Bool {
        AXIsProcessTrusted()
    }

    static func requestPermission() {
        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }

    // ── Browser detection ─────────────────────────────────────────

    /// Returns true for any known browser — uses substring matching so all
    /// Edge/Chrome/Firefox variants (Beta, Dev, Canary…) are caught.
    private func isBrowser(_ app: NSRunningApplication) -> Bool {
        guard let id = app.bundleIdentifier?.lowercased() else { return false }
        return id.contains("safari")       ||
               id.contains("chrome")       ||
               id.contains("edgemac")      ||   // Microsoft Edge (all channels)
               id.contains("edge")         ||
               id.contains("firefox")      ||
               id.contains("opera")        ||
               id.contains("brave")        ||
               id.contains("thebrowser")   ||   // Arc
               id.contains("vivaldi")      ||
               id.contains("waterfox")
    }

    // ── Private ───────────────────────────────────────────────────

    @objc private func activeAppChanged() {
        checkFrontmostApp()
    }

    private func checkFrontmostApp() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              isBrowser(app) else {
            stopPolling()
            reportClear()
            return
        }
        startPolling(for: app)
    }

    private func startPolling(for app: NSRunningApplication) {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.checkURL(in: app)
        }
        RunLoop.main.add(pollTimer!, forMode: .common)
        checkURL(in: app)
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func checkURL(in app: NSRunningApplication) {
        guard !blockedURLs.isEmpty else { reportClear(); return }
        let url = browserURL(for: app) ?? ""
        let normalised = url.lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://",  with: "")
            .replacingOccurrences(of: "www.",     with: "")

        let hit = blockedURLs.first { normalised.hasPrefix($0) || normalised.contains($0) }
        if let matched = hit {
            if !currentlyDistracted {
                currentlyDistracted = true
                onDistracted?(matched)
            }
        } else {
            reportClear()
        }
    }

    private func reportClear() {
        guard currentlyDistracted else { return }
        currentlyDistracted = false
        onCleared?()
    }

    // ── AXUIElement URL extraction ────────────────────────────────

    private func browserURL(for app: NSRunningApplication) -> String? {
        guard DistractionMonitor.hasPermission else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        // Try focused window, then main window
        var ref: CFTypeRef?
        if AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &ref) != .success {
            AXUIElementCopyAttributeValue(axApp, kAXMainWindowAttribute as CFString, &ref)
        }
        guard let window = ref as! AXUIElement? else { return nil }

        // BFS through the accessibility tree — handles any nesting depth
        return bfsURL(from: window)
    }

    private func bfsURL(from root: AXUIElement) -> String? {
        var queue: [AXUIElement] = [root]
        var visited = 0

        while !queue.isEmpty, visited < 300 {
            let element = queue.removeFirst()
            visited += 1

            // Safari exposes an AXURL attribute directly
            var urlRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, "AXURL" as CFString, &urlRef) == .success,
               let u = urlRef as? URL {
                return u.absoluteString
            }

            // Chrome / Edge / Firefox: URL bar is an AXTextField
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
            if let role = roleRef as? String, role == "AXTextField" {
                var valueRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
                   let value = valueRef as? String, isURLLike(value) {
                    return value
                }
            }

            // Enqueue children
            var childrenRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
               let children = childrenRef as? [AXUIElement] {
                queue.append(contentsOf: children)
            }
        }
        return nil
    }

    private func isURLLike(_ value: String) -> Bool {
        let v = value.lowercased()
        return v.hasPrefix("http://")  ||
               v.hasPrefix("https://") ||
               v.hasPrefix("www.")     ||
               (v.contains(".") && !v.contains(" ") && v.count > 5)
    }
}
