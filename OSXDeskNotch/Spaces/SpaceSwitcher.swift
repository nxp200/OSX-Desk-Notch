//
//  SpaceSwitcher.swift
//
//  Switches macOS Spaces by injecting Ctrl+Left / Ctrl+Right keystrokes —
//  the same shortcut the user would press. We use this rather than
//  `CGSManagedDisplaySetCurrentSpace` because that SPI silently no-ops on
//  several Sonoma builds (it updates WindowServer's internal state but
//  doesn't trigger the visual switch).
//
//  Requires:
//    * "Move left/right a space" enabled in System Settings → Keyboard
//      → Keyboard Shortcuts → Mission Control. (Enabled by default.)
//    * Accessibility permission on macOS 14.4+. We prompt on first use.
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

    /// Step the visible space `times` times in `direction`. Each press is
    /// followed by `stepDelay` so the WindowServer's switch animation can
    /// finish before the next keystroke fires (otherwise the events get
    /// coalesced and only one switch happens).
    static func step(_ direction: Direction,
                     times: Int,
                     stepDelay: TimeInterval = 0.22) async {
        guard times > 0 else { return }
        let key = direction.virtualKey
        for i in 0..<times {
            postControlKey(key)
            if i < times - 1 {
                try? await Task.sleep(nanoseconds: UInt64(stepDelay * 1_000_000_000))
            }
        }
    }

    private static func postControlKey(_ keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source,
                                 virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source,
                               virtualKey: keyCode, keyDown: false)
        else { return }
        down.flags = .maskControl
        up.flags = .maskControl
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
