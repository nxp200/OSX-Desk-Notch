//
//  SpaceSwitcher.swift
//
//  Switches macOS Spaces by injecting Ctrl+Left / Ctrl+Right keystrokes —
//  the same shortcut the user would press. We send explicit Ctrl
//  key-down/key-up events around the arrow key event (instead of just
//  setting the modifier flag) because some Sonoma builds only honour
//  Mission Control's Ctrl+Arrow shortcut when it sees real modifier
//  events, not a flag bit.
//
//  Requires:
//    * "Move left/right a space" enabled in System Settings → Keyboard
//      → Keyboard Shortcuts → Mission Control. (Enabled by default.)
//    * Accessibility permission. macOS routes synthesised events through
//      the AX allow-list since 10.14.
//

import AppKit
import CoreGraphics

@MainActor
enum SpaceSwitcher {

    enum Direction {
        case left, right

        fileprivate var virtualKey: CGKeyCode {
            switch self {
            case .left:  return 0x7B   // kVK_LeftArrow
            case .right: return 0x7C   // kVK_RightArrow
            }
        }
    }

    /// Steps the visible space `times` times in `direction`. Each press is
    /// followed by `stepDelay` so the WindowServer's switch animation can
    /// finish before the next keystroke fires (otherwise the events get
    /// coalesced and only one switch happens).
    static func step(_ direction: Direction,
                     times: Int,
                     stepDelay: TimeInterval = 0.25) async {
        guard times > 0 else { return }
        let key = direction.virtualKey
        for i in 0..<times {
            postControlArrow(key)
            if i < times - 1 {
                try? await Task.sleep(
                    nanoseconds: UInt64(stepDelay * 1_000_000_000)
                )
            }
        }
    }

    /// Sends Ctrl-down, Arrow-down (with Ctrl flag), Arrow-up (with Ctrl
    /// flag), Ctrl-up. The explicit modifier-key events make this look
    /// to WindowServer exactly like a real key press.
    private static func postControlArrow(_ arrowKey: CGKeyCode) {
        let kVK_Control: CGKeyCode = 0x3B
        let source = CGEventSource(stateID: .hidSystemState)

        let ctrlDown = CGEvent(keyboardEventSource: source,
                               virtualKey: kVK_Control, keyDown: true)
        let arrowDown = CGEvent(keyboardEventSource: source,
                                virtualKey: arrowKey, keyDown: true)
        let arrowUp = CGEvent(keyboardEventSource: source,
                              virtualKey: arrowKey, keyDown: false)
        let ctrlUp = CGEvent(keyboardEventSource: source,
                             virtualKey: kVK_Control, keyDown: false)

        arrowDown?.flags = .maskControl
        arrowUp?.flags = .maskControl

        let tap: CGEventTapLocation = .cghidEventTap
        ctrlDown?.post(tap: tap)
        arrowDown?.post(tap: tap)
        arrowUp?.post(tap: tap)
        ctrlUp?.post(tap: tap)
    }
}
