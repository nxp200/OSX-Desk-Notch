//
//  NotchWindow.swift
//
//  A transparent borderless panel that floats just under the notch.
//  Designed so the user can't drag it, focus it, or accidentally hide it.
//

import AppKit

final class NotchWindow: NSPanel {

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configure()
    }

    private func configure() {
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        isMovable = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none

        // Sit above the menu bar but below system alerts.
        level = NSWindow.Level(
            rawValue: Int(CGWindowLevelForKey(.statusWindow))
        )

        // Show on every Space, never go into Mission Control, never tile.
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]
    }

    // The panel never becomes key; we don't want to steal focus from the
    // user's frontmost app, and our SwiftUI controls work fine without it.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override var acceptsFirstResponder: Bool { false }
}
