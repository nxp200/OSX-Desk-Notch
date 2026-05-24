//
//  HoverMonitor.swift
//
//  Watches the global mouse position and emits "in hot zone" / "out of hot
//  zone" callbacks. We deliberately use `NSEvent.mouseLocation` polling on
//  a Timer rather than a global event monitor, because:
//
//    * Mouse-position polling needs **no** entitlements (no Accessibility
//      prompt, no Input Monitoring prompt). NSEvent global monitors that
//      capture mouseMoved trigger Input Monitoring on recent macOS.
//    * A 60 Hz timer in the active app is negligible CPU.
//    * Polling makes hit-testing reliably work even while another app is
//      capturing the mouse (Mission Control, screen sharing tools, etc).
//

import AppKit
import Foundation

@MainActor
final class HoverMonitor {

    enum State { case outside, inside }

    /// Called whenever the hover state transitions. Always invoked on the
    /// main actor.
    var onTransition: ((State) -> Void)?

    /// Rectangle (global screen coords) considered "inside". Updateable —
    /// when the bar is expanded, the caller widens this to the union zone.
    var hotZone: CGRect = .zero

    private var timer: Timer?
    private(set) var state: State = .outside
    private let pollInterval: TimeInterval

    init(pollInterval: TimeInterval = 1.0 / 60.0) {
        self.pollInterval = pollInterval
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        // .common keeps the timer running during menu tracking and resize.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let mouse = NSEvent.mouseLocation
        let inside = hotZone.contains(mouse)
        let newState: State = inside ? .inside : .outside
        guard newState != state else { return }
        state = newState
        onTransition?(newState)
    }
}
