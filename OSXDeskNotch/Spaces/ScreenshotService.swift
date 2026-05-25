//
//  ScreenshotService.swift
//
//  Thin wrapper around `CGWindowListCreateImage` plus the public
//  CoreGraphics permission API. Captures are RAM-only; we never write
//  them to disk and we never transmit them.
//
//  Requires the user to grant Screen Recording in
//  System Settings → Privacy & Security → Screen Recording.
//

import AppKit
import CoreGraphics

@MainActor
enum ScreenshotService {

    /// Returns true if the OS has granted Screen Recording permission.
    static func hasPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Triggers the system prompt the first time, otherwise no-ops. Returns
    /// the current authorization state immediately after.
    @discardableResult
    static func requestPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    /// Captures the full bounds of the supplied display. Returns nil if
    /// permission has not been granted or the SPI failed.
    static func capture(displayID: CGDirectDisplayID) -> NSImage? {
        guard hasPermission() else { return nil }
        let bounds = CGDisplayBounds(displayID)

        guard let cgImage = CGWindowListCreateImage(
            bounds,
            [.optionOnScreenOnly],
            kCGNullWindowID,
            [.nominalResolution, .boundsIgnoreFraming]
        ) else {
            return nil
        }

        let image = NSImage(cgImage: cgImage, size: bounds.size)
        image.cacheMode = .never
        return image
    }
}
