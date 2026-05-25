//
//  SpaceSwitcher.swift
//
//  Switches macOS Spaces by injecting Ctrl+Arrow — the same keystroke the
//  user would press. Two paths, tried in order:
//
//   1. AppleScript via System Events ("Automation" permission). Easier to
//      grant: one click in the system prompt, tied to bundle ID rather
//      than code signature, survives Xcode rebuilds.
//
//   2. CGEvent.post ("Accessibility" permission). Lower level; only used
//      if AppleScript fails. Sensitive to code-signature changes — a
//      common dev-build pain point where the toggle reads "on" but
//      AXIsProcessTrusted still returns false until the user toggles it
//      off and on again.
//
//  Both routes drive WindowServer's own "Move left/right a space" handler
//  ("Move left/right a space" must be enabled in System Settings →
//  Keyboard → Keyboard Shortcuts → Mission Control — it is by default).
//

import AppKit
import CoreGraphics
import Foundation

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

        fileprivate var appleScriptKeyCode: Int {
            switch self {
            case .left:  return 123
            case .right: return 124
            }
        }
    }

    /// Steps the visible space `times` times in `direction`. Returns true
    /// if a switch path was successfully invoked; false if neither
    /// Automation nor Accessibility is available.
    @discardableResult
    static func step(_ direction: Direction,
                     times: Int,
                     stepDelay: TimeInterval = 0.22) async -> Bool {
        guard times > 0 else { return false }

        // Primary: AppleScript → System Events (Automation permission).
        if await runAppleScriptPath(
            direction: direction, times: times, stepDelay: stepDelay
        ) {
            return true
        }

        // Fallback: CGEvent injection (Accessibility permission).
        if AccessibilityPermission.isGranted {
            await runCGEventPath(
                direction: direction, times: times, stepDelay: stepDelay
            )
            return true
        }

        Diagnostics.switcher.error(
            "no switch path available — Automation denied and Accessibility not granted"
        )
        return false
    }

    // MARK: - Path 1: AppleScript / Automation

    private static func runAppleScriptPath(
        direction: Direction,
        times: Int,
        stepDelay: TimeInterval
    ) async -> Bool {
        let key = direction.appleScriptKeyCode
        for i in 0..<times {
            guard await dispatchAppleScript(keyCode: key) else { return false }
            if i < times - 1 {
                try? await Task.sleep(
                    nanoseconds: UInt64(stepDelay * 1_000_000_000)
                )
            }
        }
        Diagnostics.switcher.info(
            "AppleScript path switched \(times) step(s) \(direction == .right ? "right" : "left", privacy: .public)"
        )
        return true
    }

    /// Executes the AppleScript on a background queue so we don't block
    /// the main actor during the round-trip to System Events. Returns
    /// false on any error (we log the code/message via os.Logger).
    private static func dispatchAppleScript(keyCode: Int) async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let source = """
                tell application "System Events" to key code \(keyCode) using control down
                """
                guard let script = NSAppleScript(source: source) else {
                    Diagnostics.switcher.error("NSAppleScript init failed")
                    continuation.resume(returning: false)
                    return
                }
                var errorInfo: NSDictionary?
                _ = script.executeAndReturnError(&errorInfo)
                if let errorInfo {
                    let code = (errorInfo["NSAppleScriptErrorNumber"] as? Int) ?? 0
                    let message = (errorInfo["NSAppleScriptErrorMessage"] as? String)
                        ?? "(no message)"
                    Diagnostics.switcher.error(
                        "AppleScript error \(code): \(message, privacy: .public)"
                    )
                    continuation.resume(returning: false)
                    return
                }
                continuation.resume(returning: true)
            }
        }
    }

    // MARK: - Path 2: CGEvent / Accessibility

    private static func runCGEventPath(
        direction: Direction,
        times: Int,
        stepDelay: TimeInterval
    ) async {
        let key = direction.virtualKey
        for i in 0..<times {
            postControlArrow(key)
            if i < times - 1 {
                try? await Task.sleep(
                    nanoseconds: UInt64(stepDelay * 1_000_000_000)
                )
            }
        }
        Diagnostics.switcher.info("CGEvent path switched \(times) step(s)")
    }

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
