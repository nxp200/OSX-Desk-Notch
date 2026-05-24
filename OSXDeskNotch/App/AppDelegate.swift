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
}
