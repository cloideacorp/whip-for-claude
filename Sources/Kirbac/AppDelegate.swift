import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var whipController: WhipWindowController?
    private lazy var statusMenu: NSMenu = {
        let menu = NSMenu()
        let quitItem = NSMenuItem(title: L10n.quit, action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        return menu
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        button.image = Self.makeWhipIcon()
        button.imagePosition = .imageOnly
        button.toolTip = L10n.tooltip
        button.target = self
        button.action = #selector(statusClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private static func makeWhipIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let path = NSBezierPath()
            path.move(to: NSPoint(x: 12.5, y: 3.5))
            path.line(to: NSPoint(x: 14.5, y: 6.5))
            path.curve(
                to: NSPoint(x: 4.5, y: 14.5),
                controlPoint1: NSPoint(x: 15.5, y: 11),
                controlPoint2: NSPoint(x: 10, y: 16)
            )
            path.curve(
                to: NSPoint(x: 2.5, y: 8),
                controlPoint1: NSPoint(x: 1.5, y: 13.5),
                controlPoint2: NSPoint(x: 1.5, y: 10)
            )
            NSColor.black.setStroke()
            path.lineWidth = 1.6
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }

    @objc private func statusClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent,
              let button = statusItem.button else {
            toggleWhip()
            return
        }
        if event.type == .rightMouseUp {
            let point = NSPoint(x: button.bounds.midX, y: button.bounds.minY - 2)
            statusMenu.popUp(positioning: nil, at: point, in: button)
            return
        }
        toggleWhip()
    }

    private func toggleWhip() {
        if let whip = whipController, whip.isVisible {
            whip.dropWhip()
            return
        }
        guard ensureAccessibility() else { return }
        if whipController == nil {
            whipController = WhipWindowController()
            whipController?.onHidden = { [weak self] in
                self?.whipController = nil
            }
        }
        whipController?.showWhip()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func ensureAccessibility() -> Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(opts) {
            return true
        }
        let alert = NSAlert()
        alert.messageText = L10n.accessibilityTitle
        alert.informativeText = L10n.accessibilityBody
        alert.addButton(withTitle: L10n.openSettings)
        alert.addButton(withTitle: L10n.ok)
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
        return false
    }
}
