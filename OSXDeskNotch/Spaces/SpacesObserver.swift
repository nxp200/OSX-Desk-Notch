//
//  SpacesObserver.swift
//
//  Observable wrapper that re-queries the SPI whenever the system tells us
//  the active space changed. The published `current` snapshot drives the UI.
//

import AppKit
import Combine

@MainActor
final class SpacesObserver: ObservableObject {

    @Published private(set) var current: DisplaySpaces?

    private let service: SpacesProviding
    private var observers: [NSObjectProtocol] = []

    init(service: SpacesProviding) {
        self.service = service
        subscribe()
        refresh()
    }

    deinit {
        for token in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
    }

    /// Force a re-read of the SPI (e.g. when the hover bar is opening).
    func refresh() {
        guard let screen = NSScreen.screens.first(where: { $0.hasNotch })
                ?? NSScreen.main else {
            current = nil
            return
        }
        current = service.snapshot(for: screen)
    }

    func activateSpace(_ space: Space) {
        guard let snapshot = current else { return }
        service.activate(spaceID: space.id, on: snapshot.displayUUID)
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
            }
        }
        observers.append(token)
    }
}
