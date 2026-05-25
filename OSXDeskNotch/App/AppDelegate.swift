//
//  AppDelegate.swift
//

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var environment: AppEnvironment?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let env = AppEnvironment()
        self.environment = env
        env.notchController.start()
        installStatusItem()
        // Nudge for the two permissions we rely on. Both are no-ops if
        // they've already been granted; both surface the standard macOS
        // prompt on first launch.
        if !ScreenshotService.hasPermission() {
            ScreenshotService.requestPermission()
        }
        if !AccessibilityPermission.isGranted {
            AccessibilityPermission.request()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        environment?.notchController.stop()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    // MARK: - Status item

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let image = NSImage(
                systemSymbolName: "rectangle.3.group",
                accessibilityDescription: "OSX Desk Notch"
            )
            image?.isTemplate = true
            button.image = image
        }

        let menu = NSMenu()

        let about = NSMenuItem(
            title: "About OSX Desk Notch",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())

        let screenRecording = NSMenuItem(
            title: "Screen Recording Permission…",
            action: #selector(openScreenRecordingSettings),
            keyEquivalent: ""
        )
        screenRecording.target = self
        menu.addItem(screenRecording)

        let accessibility = NSMenuItem(
            title: "Accessibility Permission…",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        accessibility.target = self
        menu.addItem(accessibility)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit OSX Desk Notch",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)

        item.menu = menu
        self.statusItem = item
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openScreenRecordingSettings() {
        if !ScreenshotService.hasPermission() {
            // First nudge — triggers the OS prompt if it hasn't already.
            ScreenshotService.requestPermission()
        }
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        )
        if let url {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openAccessibilitySettings() {
        if !AccessibilityPermission.isGranted {
            AccessibilityPermission.request()
        }
        AccessibilityPermission.openSettings()
    }
}
