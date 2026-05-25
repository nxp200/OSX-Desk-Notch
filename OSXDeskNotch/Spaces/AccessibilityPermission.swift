//
//  AccessibilityPermission.swift
//
//  Public AX API wrapper. macOS 14.4+ requires apps that inject keyboard
//  events via `CGEvent.post` to be in the Accessibility allow-list. The
//  user grants this in System Settings → Privacy & Security → Accessibility.
//

import ApplicationServices
import AppKit

@MainActor
enum AccessibilityPermission {

    /// Whether the current process is currently in the AX allow-list.
    static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Triggers the system prompt asking the user to grant Accessibility.
    /// No-op if already granted. Returns the state immediately after the
    /// call (the user may still need to flip the toggle in Settings).
    @discardableResult
    static func request() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
        let options: CFDictionary = [key: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Opens the Privacy & Security → Accessibility settings pane.
    static func openSettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )
        if let url {
            NSWorkspace.shared.open(url)
        }
    }
}
