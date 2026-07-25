import Foundation

enum L10n {
    static var isTurkish: Bool {
        Locale.preferredLanguages.first?.hasPrefix("tr") == true
    }

    static var quit: String { isTurkish ? "Çıkış" : "Quit" }
    static var tooltip: String { isTurkish ? "Kırbaç — tıkla" : "Kırbaç — click" }

    static var accessibilityTitle: String {
        isTurkish ? "Kırbaç — Erişilebilirlik" : "Kırbaç — Accessibility"
    }

    static var accessibilityBody: String {
        if isTurkish {
            return "Klavye göndermek için Sistem Ayarları → Gizlilik ve Güvenlik → Erişilebilirlik’ten Kırbaç’a izin ver."
        }
        return "To send keystrokes, allow Kırbaç under System Settings → Privacy & Security → Accessibility."
    }

    static var openSettings: String { isTurkish ? "Ayarları Aç" : "Open Settings" }
    static var ok: String { isTurkish ? "Tamam" : "OK" }

    static var phrases: [String] {
        if isTurkish {
            return [
                "DAHA HIZLI",
                "HIZLAN",
                "HIZLAN CLANKER",
                "IS BITIR",
                "CALIS DAHA HIZLI",
                "GO FASTER",
                "FASTER",
            ]
        }
        return [
            "FASTER",
            "GO FASTER",
            "Work FASTER",
            "Speed it up",
            "FASTER CLANKER",
            "Hurry up",
            "Pick up the pace",
        ]
    }
}
