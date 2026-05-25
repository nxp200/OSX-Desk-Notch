//
//  SpacePreviewStore.swift
//
//  In-memory cache of per-space thumbnails. Each spaceID has its own
//  pending capture task — a new capture for the same space supersedes the
//  previous, but captures for *different* spaces run in parallel so
//  rapid-fire switches don't lose intermediate thumbnails.
//

import AppKit

@MainActor
final class SpacePreviewStore: ObservableObject {

    /// Keyed by CGSSpaceID.
    @Published private(set) var previews: [UInt64: NSImage] = [:]

    private var pending: [UInt64: Task<Void, Never>] = [:]

    /// Drop everything (used when the screen layout changes).
    func reset() {
        for task in pending.values { task.cancel() }
        pending.removeAll()
        previews.removeAll()
    }

    /// Schedule a capture for the supplied space. The capture is delayed
    /// by `delay` so any animation can finish first; queueing another
    /// capture for the *same* space supersedes the previous one.
    func scheduleCapture(for spaceID: UInt64,
                         on screen: NSScreen,
                         delay: TimeInterval = 0.30) {
        guard let displayID = Self.displayID(for: screen) else { return }

        pending[spaceID]?.cancel()
        pending[spaceID] = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            if let image = await ScreenshotService.capture(displayID: displayID),
               !Task.isCancelled {
                self.previews[spaceID] = image
            }
            self.pending[spaceID] = nil
        }
    }

    func image(for spaceID: UInt64) -> NSImage? {
        previews[spaceID]
    }

    private static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
    }
}
