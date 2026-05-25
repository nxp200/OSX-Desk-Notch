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

    enum Outcome: Equatable {
        /// One of the switch paths reported success.
        case success
        /// We reached System Events but it (or CGEvent) refused the keystroke
        /// because the calling process isn't in the Accessibility allow-list.
        /// Most common dev-build cause: stale TCC entry after a rebuild.
        case needsAccessibility
        /// We couldn't even talk to System Events — Automation permission was
        /// denied or never asked.
        case needsAutomation
    }

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

    /// Steps the visible space `times` times in `direction`. Returns the
    /// classified outcome so callers can surface the right alert.
    static func step(_ direction: Direction,
                     times: Int,
                     stepDelay: TimeInterval = 0.22) async -> Outcome {
        guard times > 0 else { return .success }

        // Primary: AppleScript → System Events.
        let asOutcome = await runAppleScriptPath(
            direction: direction, times: times, stepDelay: stepDelay
        )
        if asOutcome == .success { return .success }

        // Fallback: CGEvent — same Accessibility requirement, but worth a
        // shot in case Automation was the only thing missing.
        if AccessibilityPermission.isGranted {
            await runCGEventPath(
                direction: direction, times: times, stepDelay: stepDelay
            )
            return .success
        }

        Diagnostics.switcher.error(
            "no switch path available — \(String(describing: asOutcome), privacy: .public)"
        )
        return asOutcome
    }

    // MARK: - Path 1: AppleScript / Automation

    private static func runAppleScriptPath(
        direction: Direction,
        times: Int,
        stepDelay: TimeInterval
    ) async -> Outcome {
        let key = direction.appleScriptKeyCode
        for i in 0..<times {
            let errorCode = await dispatchAppleScript(keyCode: key)
            if errorCode != 0 {
                return classify(appleScriptError: errorCode)
            }
            if i < times - 1 {
                try? await Task.sleep(
                    nanoseconds: UInt64(stepDelay * 1_000_000_000)
                )
            }
        }
        Diagnostics.switcher.info(
            "AppleScript path switched \(times) step(s) \(direction == .right ? "right" : "left", privacy: .public)"
        )
        return .success
    }

    private static func classify(appleScriptError code: Int) -> Outcome {
        switch code {
        case 1002:
            // "System Events got an error: <app> is not allowed to send
            // keystrokes." → System Events demands Accessibility.
            return .needsAccessibility
        case -1743:
            // errAEEventNotPermitted → user denied the Automation prompt.
            return .needsAutomation
        default:
            return .needsAccessibility
        }
    }

    /// Executes the AppleScript on a background queue so we don't block
    /// the main actor during the round-trip to System Events. Returns
    /// 0 on success, otherwise the AppleScript error number.
    private static func dispatchAppleScript(keyCode: Int) async -> Int {
        await withCheckedContinuation { (continuation: CheckedContinuation<Int, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let source = """
                tell application "System Events" to key code \(keyCode) using control down
                """
                guard let script = NSAppleScript(source: source) else {
                    Diagnostics.switcher.error("NSAppleScript init failed")
                    continuation.resume(returning: -1)
                    return
                }
                var errorInfo: NSDictionary?
                _ = script.executeAndReturnError(&errorInfo)
                if let errorInfo {
                    let code = (errorInfo["NSAppleScriptErrorNumber"] as? Int) ?? -1
                    let message = (errorInfo["NSAppleScriptErrorMessage"] as? String)
                        ?? "(no message)"
                    Diagnostics.switcher.error(
                        "AppleScript error \(code): \(message, privacy: .public)"
                    )
                    continuation.resume(returning: code)
                    return
                }
                continuation.resume(returning: 0)
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
