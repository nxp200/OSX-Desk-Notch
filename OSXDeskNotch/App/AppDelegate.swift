//
//  AppDelegate.swift
//

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var environment: AppEnvironment?
    private var statusItem: NSStatusItem?
    private var screenRecordingItem: NSMenuItem?
    private var automationItem: NSMenuItem?
    private var accessibilityItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let env = AppEnvironment()
        self.environment = env
        env.notchController.start()
        installStatusItem()

        // Screen Recording is the only permission that benefits from an
        // early prompt — previews need it before the user has ever
        // clicked anything. Automation gets prompted lazily, the first
        // time the user actually triggers a switch.
        if !ScreenshotService.hasPermission() {
            ScreenshotService.requestPermission()
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
        let item = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        if let button = item.button {
            let image = NSImage(
                systemSymbolName: "rectangle.3.group",
                accessibilityDescription: "OSX Desk Notch"
            )
            image?.isTemplate = true
            button.image = image
        }

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        let about = NSMenuItem(
            title: "About OSX Desk Notch",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())

        let sr = NSMenuItem(
            title: "Screen Recording…",
            action: #selector(openScreenRecordingSettings),
            keyEquivalent: ""
        )
        sr.target = self
        menu.addItem(sr)
        screenRecordingItem = sr

        let auto = NSMenuItem(
            title: "Automation…",
            action: #selector(openAutomationSettings),
            keyEquivalent: ""
        )
        auto.target = self
        menu.addItem(auto)
        automationItem = auto

        let ax = NSMenuItem(
            title: "Accessibility (fallback)…",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        ax.target = self
        menu.addItem(ax)
        accessibilityItem = ax

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

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        refreshPermissionTitles()
    }

    private func refreshPermissionTitles() {
        let sr = ScreenshotService.hasPermission()
        screenRecordingItem?.title = sr
            ? "Screen Recording ✓"
            : "Screen Recording — not granted…"

        // Automation status is per-target; we ask about System Events
        // specifically because that's what we use for switching.
        let automation = AutomationPermission.statusForSystemEvents()
        switch automation {
        case .granted:
            automationItem?.title = "Automation (System Events) ✓"
        case .denied:
            automationItem?.title = "Automation (System Events) — denied…"
        case .notDetermined:
            automationItem?.title = "Automation (System Events) — not asked…"
        }

        let ax = AccessibilityPermission.isGranted
        accessibilityItem?.title = ax
            ? "Accessibility (fallback) ✓"
            : "Accessibility (fallback) — not granted…"
    }

    // MARK: - Actions

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openScreenRecordingSettings() {
        if !ScreenshotService.hasPermission() {
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

    @objc private func openAutomationSettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        )
        if let url {
            NSWorkspace.shared.open(url)
        }
    }
}
