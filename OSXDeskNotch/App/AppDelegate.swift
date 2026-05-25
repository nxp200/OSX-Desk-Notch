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
    private var accessibilityItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let env = AppEnvironment()
        self.environment = env
        env.notchController.start()
        installStatusItem()

        // Both permissions are no-ops if already granted; both surface the
        // standard macOS prompt on first launch.
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

        let ax = NSMenuItem(
            title: "Accessibility…",
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

        let ax = AccessibilityPermission.isGranted
        accessibilityItem?.title = ax
            ? "Accessibility ✓"
            : "Accessibility — not granted…"
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
}
