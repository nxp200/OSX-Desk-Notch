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
        guard let snapshot = current else { return }
        service.activate(spaceID: space.id, on: snapshot.displayUUID)
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
