//
//  OSXDeskNotchApp.swift
//

import SwiftUI

@main
struct OSXDeskNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // No standard windows — UI is the menu-bar item plus the notch overlay.
        Settings {
            EmptyView()
        }
    }
}
