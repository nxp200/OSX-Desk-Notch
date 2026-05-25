//
//  SpacePreviewStore.swift
//
//  In-memory cache of per-space thumbnails. Captures are taken shortly
//  after the active space changes (so the new desktop has time to settle)
//  and overwrite any previous capture for that space.
//

import AppKit

@MainActor
final class SpacePreviewStore: ObservableObject {

    /// Keyed by CGSSpaceID.
    @Published private(set) var previews: [UInt64: NSImage] = [:]

    private var pendingCapture: Task<Void, Never>?

    /// Drop everything (used when the screen layout changes).
    func reset() {
        pendingCapture?.cancel()
        pendingCapture = nil
        previews.removeAll()
    }

    /// Schedule a capture for the currently-visible space. The capture is
    /// delayed slightly to let any switch animation finish. If another
    /// capture is requested before this one runs, the previous is cancelled.
    func scheduleCapture(for spaceID: UInt64,
                         on screen: NSScreen,
                         delay: TimeInterval = 0.30) {
        guard let displayID = Self.displayID(for: screen) else { return }
        pendingCapture?.cancel()
        pendingCapture = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            if let image = ScreenshotService.capture(displayID: displayID) {
                self.previews[spaceID] = image
            }
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
