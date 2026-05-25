//
//  SpacesObserver.swift
//
//  Observable wrapper that re-queries the SPI whenever the system tells us
//  the active space changed. The published `current` snapshot drives the UI,
//  and each space change also triggers a thumbnail capture.
//

import AppKit
import Combine

@MainActor
final class SpacesObserver: ObservableObject {

    @Published private(set) var current: DisplaySpaces?

    let previews: SpacePreviewStore

    private let service: SpacesProviding
    private var observers: [NSObjectProtocol] = []

    init(service: SpacesProviding, previews: SpacePreviewStore) {
        self.service = service
        self.previews = previews
        subscribe()
        refresh()
        captureCurrentIfPossible()
    }

    deinit {
        for token in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
    }

    /// Force a re-read of the SPI (e.g. when the hover bar is opening).
    func refresh() {
        guard let screen = bestScreen() else {
            current = nil
            return
        }
        current = service.snapshot(for: screen)
    }

    func activateSpace(_ space: Space) {
        guard let snapshot = current else {
            Diagnostics.switcher.error("activate called with no snapshot")
            return
        }
        guard let currentIndex = snapshot.spaces.firstIndex(where: {
            $0.id == snapshot.currentSpaceID
        }) else {
            Diagnostics.switcher.error(
                "current space \(snapshot.currentSpaceID) not in spaces list"
            )
            return
        }
        guard let targetIndex = snapshot.spaces.firstIndex(where: {
            $0.id == space.id
        }) else {
            Diagnostics.switcher.error("target space \(space.id) not in spaces list")
            return
        }

        let delta = targetIndex - currentIndex
        guard delta != 0 else { return }

        let direction: SpaceSwitcher.Direction = delta > 0 ? .right : .left
        let steps = abs(delta)
        Diagnostics.switcher.info(
            "request: \(steps) steps \(delta > 0 ? "right" : "left", privacy: .public)"
        )

        Task { [weak self] in
            let outcome = await SpaceSwitcher.step(direction, times: steps)
            switch outcome {
            case .success:
                break
            case .needsAccessibility:
                self?.showAccessibilityRequiredAlert()
            case .needsAutomation:
                self?.showAutomationRequiredAlert()
            }
        }
    }

    private func showAccessibilityRequiredAlert() {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.osxdesknotch.OSXDeskNotch"
        let resetCommand = "tccutil reset Accessibility \(bundleID)"

        let alert = NSAlert()
        alert.messageText = "Re-grant Accessibility for OSX Desk Notch"
        alert.informativeText = """
            macOS blocked the keystroke because the Accessibility entry \
            for this build is stale. (This is a common Xcode dev-build \
            issue — every rebuild changes the binary's code signature \
            and invalidates the TCC entry even though the checkbox \
            still shows it as on.)

            Fix it once:

            1. Click "Open Accessibility Settings" below.
            2. Find OSX Desk Notch in the list and click the – button \
               to REMOVE the existing entry (don't just toggle off).
            3. Quit and rebuild this app (Stop ▢, then ⌘R in Xcode).
            4. Click any desktop tile again — macOS will prompt for \
               Accessibility, click Allow, and switching will work.

            If macOS won't show the – button, use the "Copy reset \
            command" option below and paste it into Terminal.
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Accessibility Settings")
        alert.addButton(withTitle: "Copy reset command")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            AccessibilityPermission.openSettings()
        case .alertSecondButtonReturn:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(resetCommand, forType: .string)
        default:
            break
        }
    }

    private func showAutomationRequiredAlert() {
        let alert = NSAlert()
        alert.messageText = "Allow OSX Desk Notch to control System Events"
        alert.informativeText = """
            OSX Desk Notch sends Control+Arrow via System Events to switch \
            desktops. You previously denied that prompt, so it's now \
            disabled.

            Open System Settings → Privacy & Security → Automation, \
            expand OSX Desk Notch, and enable the System Events toggle.
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Automation Settings")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let url = URL(
                string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
            )
            if let url {
                NSWorkspace.shared.open(url)
            }
        }
    }

    /// Take a snapshot of the currently visible space and cache it. Safe to
    /// call any time; will be a no-op if Screen Recording isn't authorised.
    /// The optional `after` delay lets the caller wait for transitions or
    /// fades to finish before the screenshot is taken.
    func captureCurrentIfPossible(after delay: TimeInterval = 0.30) {
        guard let screen = bestScreen(),
              let snapshot = current ?? service.snapshot(for: screen)
        else { return }
        previews.scheduleCapture(
            for: snapshot.currentSpaceID, on: screen, delay: delay
        )
    }

    // MARK: - Private

    private func bestScreen() -> NSScreen? {
        NSScreen.screens.first(where: { $0.hasNotch }) ?? NSScreen.main
    }

    private func subscribe() {
        let nc = NSWorkspace.shared.notificationCenter
        let token = nc.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
                // 0.6s gives the WindowServer space-switch animation enough
                // time to land — capturing earlier sometimes snapped the
                // outgoing desktop and mis-filed it under the new space.
                self?.captureCurrentIfPossible(after: 0.6)
            }
        }
        observers.append(token)
    }
}
