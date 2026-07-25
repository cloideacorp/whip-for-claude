import Foundation
import Carbon.HIToolbox

enum MacroSender {
    static func crack() {
        let phrase = L10n.phrases.randomElement() ?? "FASTER"
        sendKey(cgKeyCode: CGKeyCode(kVK_ANSI_C), flags: .maskControl)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            typeText(phrase)
            sendKey(cgKeyCode: CGKeyCode(kVK_Return), flags: [])
        }
    }

    private static func sendKey(cgKeyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: cgKeyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: cgKeyCode, keyDown: false) else { return }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private static func typeText(_ text: String) {
        let source = CGEventSource(stateID: .hidSystemState)
        for ch in text.utf16 {
            var char = ch
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { continue }
            down.keyboardSetUnicodeString(stringLength: 1, unicodeString: &char)
            up.keyboardSetUnicodeString(stringLength: 1, unicodeString: &char)
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }
}
