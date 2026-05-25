//
//  NotchWindowController.swift
//
//  Coordinates the notch overlay's lifecycle. Owns:
//    * the transparent panel
//    * the SwiftUI host
//    * the hover monitor
//    * the geometry recomputation when displays or space data change
//

import AppKit
import Combine
import SwiftUI

@MainActor
final class NotchWindowController {

    private let spaces: SpacesObserver
    private let monitor = HoverMonitor()
    private var window: NotchWindow?
    private var geometry: NotchGeometry?
    private var hideWorkItem: DispatchWorkItem?
    private var displayObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()

    private var isExpanded = false

    init(spaces: SpacesObserver) {
        self.spaces = spaces
    }

    func start() {
        installWindow()
        installDisplayObserver()
        subscribeToSpaceChanges()
        monitor.onTransition = { [weak self] state in
            self?.handleHover(state)
        }
        monitor.start()
    }

    func stop() {
        monitor.stop()
        window?.orderOut(nil)
        window = nil
        cancellables.removeAll()
        if let displayObserver {
            NotificationCenter.default.removeObserver(displayObserver)
            self.displayObserver = nil
        }
    }

    // MARK: - Setup

    private func installWindow() {
        guard let screen = NSScreen.screens.first(where: { $0.hasNotch })
                ?? NSScreen.main else { return }
        let tileCount = spaces.current?.userSpaces.count ?? 0
        guard let geometry = NotchGeometry.compute(
            for: screen, tileCount: tileCount
        ) else { return }
        self.geometry = geometry

        let window = NotchWindow(contentRect: geometry.barRect)
        let host = NSHostingView(
            rootView: NotchBarView(
                spaces: spaces,
                previews: spaces.previews,
                onSelect: { [weak self] space in
                    self?.handleSelection(space)
                }
            )
            .environment(\.notchWidth, geometry.notchRect.width)
        )
        host.frame = NSRect(origin: .zero, size: geometry.barRect.size)
        host.autoresizingMask = [.width, .height]
        window.contentView = host
        window.setFrame(geometry.barRect, display: false)
        window.alphaValue = 0
        window.orderFrontRegardless()
        self.window = window

        updateHoverZone()
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

    private func subscribeToSpaceChanges() {
        spaces.$current
            .removeDuplicates { $0?.userSpaces.count == $1?.userSpaces.count }
            .sink { [weak self] _ in
                self?.resizeForCurrentData()
            }
            .store(in: &cancellables)
    }

    private func reinstallForCurrentScreens() {
        stop()
        installWindow()
        installDisplayObserver()
        subscribeToSpaceChanges()
        monitor.onTransition = { [weak self] state in
            self?.handleHover(state)
        }
        monitor.start()
    }

    /// Recompute geometry for the current tile count and resize the window
    /// in place, animating the resize so the bar grows/shrinks smoothly.
    private func resizeForCurrentData() {
        guard let window,
              let screen = NSScreen.screens.first(where: { $0.hasNotch })
                ?? NSScreen.main else { return }
        let tileCount = spaces.current?.userSpaces.count ?? 0
        guard let geometry = NotchGeometry.compute(
            for: screen, tileCount: tileCount
        ) else { return }
        self.geometry = geometry
        window.setFrame(geometry.barRect, display: true, animate: isExpanded)
        updateHoverZone()
    }

    private func updateHoverZone() {
        guard let geometry else { return }
        monitor.hotZone = isExpanded ? geometry.hoverZone : geometry.notchRect
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
        guard !isExpanded else { return }
        isExpanded = true
        spaces.refresh()
        updateHoverZone()
        window?.ignoresMouseEvents = false
        animateAlpha(to: 1, duration: 0.18)
    }

    private func collapse() {
        guard isExpanded else { return }
        isExpanded = false
        updateHoverZone()
        window?.ignoresMouseEvents = true
        animateAlpha(to: 0, duration: 0.22)
        // The bar is now fading away; once it's fully invisible, snap a
        // fresh capture of whatever desktop is currently visible. This is
        // what keeps the "current" tile up-to-date even when the user
        // switched via a keyboard shortcut and never triggered the bar.
        spaces.captureCurrentIfPossible(after: 0.35)
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
