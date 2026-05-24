//
//  NotchWindowController.swift
//
//  Coordinates the notch overlay's lifecycle. Owns:
//    * the transparent panel
//    * the SwiftUI host
//    * the hover monitor
//    * the geometry recomputation when displays change
//

import AppKit
import SwiftUI

@MainActor
final class NotchWindowController {

    private let spaces: SpacesObserver
    private let monitor = HoverMonitor()
    private var window: NotchWindow?
    private var geometry: NotchGeometry?
    private var hideWorkItem: DispatchWorkItem?
    private var displayObserver: NSObjectProtocol?

    private var isExpanded = false

    init(spaces: SpacesObserver) {
        self.spaces = spaces
    }

    func start() {
        installWindow()
        installDisplayObserver()
        monitor.onTransition = { [weak self] state in
            self?.handleHover(state)
        }
        monitor.start()
    }

    func stop() {
        monitor.stop()
        window?.orderOut(nil)
        window = nil
        if let displayObserver {
            NotificationCenter.default.removeObserver(displayObserver)
            self.displayObserver = nil
        }
    }

    // MARK: - Setup

    private func installWindow() {
        guard let screen = NSScreen.screens.first(where: { $0.hasNotch })
                ?? NSScreen.main else { return }
        guard let geometry = NotchGeometry.compute(for: screen) else { return }
        self.geometry = geometry

        let window = NotchWindow(contentRect: geometry.barRect)
        let host = NSHostingView(
            rootView: NotchBarView(spaces: spaces) { [weak self] space in
                self?.handleSelection(space)
            }
            .environment(\.notchWidth, geometry.notchRect.width)
        )
        host.frame = NSRect(origin: .zero, size: geometry.barRect.size)
        host.autoresizingMask = [.width, .height]
        window.contentView = host
        window.setFrame(geometry.barRect, display: false)
        window.alphaValue = 0
        window.orderFrontRegardless()
        self.window = window

        monitor.hotZone = geometry.notchRect
    }

    private func installDisplayObserver() {
        let nc = NotificationCenter.default
        displayObserver = nc.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.reinstallForCurrentScreens()
            }
        }
    }

    private func reinstallForCurrentScreens() {
        stop()
        installWindow()
        installDisplayObserver()
        monitor.onTransition = { [weak self] state in
            self?.handleHover(state)
        }
        monitor.start()
    }

    // MARK: - Hover

    private func handleHover(_ state: HoverMonitor.State) {
        switch state {
        case .inside:
            cancelPendingHide()
            expand()
        case .outside:
            scheduleHide()
        }
    }

    private func expand() {
        guard let geometry, !isExpanded else { return }
        isExpanded = true
        monitor.hotZone = geometry.hoverZone
        spaces.refresh()
        animateAlpha(to: 1, duration: 0.18)
    }

    private func collapse() {
        guard let geometry, isExpanded else { return }
        isExpanded = false
        monitor.hotZone = geometry.notchRect
        animateAlpha(to: 0, duration: 0.22)
    }

    private func scheduleHide() {
        cancelPendingHide()
        let item = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                self?.collapse()
            }
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: item)
    }

    private func cancelPendingHide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
    }

    private func animateAlpha(to value: CGFloat, duration: TimeInterval) {
        guard let window else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = value
        }
    }

    // MARK: - Actions

    private func handleSelection(_ space: Space) {
        spaces.activateSpace(space)
        // Auto-collapse shortly after a switch — feels snappier.
        scheduleHide()
    }
}
