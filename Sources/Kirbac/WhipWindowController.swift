import AppKit

final class WhipWindowController: NSWindowController {
    var onHidden: (() -> Void)?
    private var whipView: WhipView!
    private var fallenArmed = false

    var isVisible: Bool {
        window?.isVisible == true
    }

    convenience init() {
        let screen = NSScreen.main?.frame ?? .zero
        let window = NSWindow(
            contentRect: screen,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hasShadow = false
        self.init(window: window)

        whipView = WhipView(frame: screen)
        window.contentView = whipView
        whipView.onCrack = {
            MacroSender.crack()
        }
        whipView.onFallen = { [weak self] in
            guard let self, self.fallenArmed else { return }
            self.fallenArmed = false
            self.window?.orderOut(nil)
            self.onHidden?()
        }
    }

    func showWhip() {
        guard let window, let screen = NSScreen.main else { return }
        window.setFrame(screen.frame, display: true)
        whipView.frame = window.contentView?.bounds ?? CGRect(origin: .zero, size: screen.frame.size)
        fallenArmed = false
        window.makeKeyAndOrderFront(nil)
        whipView.spawn()
        fallenArmed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            Self.refocusPreviousApp()
        }
    }

    func dropWhip() {
        whipView.drop()
    }

    private static func refocusPreviousApp() {
        let script = """
        tell application "System Events"
          key down command
          key code 48
          key up command
        end tell
        """
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
        }
    }
}
