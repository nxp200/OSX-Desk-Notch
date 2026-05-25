//
//  ScreenshotService.swift
//
//  Captures the visible desktop using ScreenCaptureKit. We had to move off
//  `CGWindowListCreateImage` because it's deprecated on macOS 14 and is
//  known to return empty / black images on several Sonoma builds even when
//  Screen Recording is granted.
//
//  SCContentFilter lets us *exclude our own app* from the capture, so the
//  hover bar can be visible while we screenshot — no fade-out timing
//  dance required.
//
//  Captures stay in RAM only. They are never written to disk and never
//  transmitted.
//

import AppKit
import CoreGraphics
import ScreenCaptureKit

@MainActor
enum ScreenshotService {

    /// Returns true if Screen Recording is currently authorised. Uses the
    /// public CG preflight call which checks live TCC state.
    static func hasPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Triggers the system permission prompt the first time, otherwise
    /// no-ops. Returns the authorisation state right after the call.
    @discardableResult
    static func requestPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    /// Captures the supplied display, excluding our own bar from the frame.
    /// Returns nil if permission isn't granted, the display can't be found,
    /// or ScreenCaptureKit raised an error.
    static func capture(displayID: CGDirectDisplayID) async -> NSImage? {
        guard hasPermission() else {
            Diagnostics.previews.error(
                "capture skipped — Screen Recording not granted"
            )
            return nil
        }

        do {
            let content = try await SCShareableContent
                .excludingDesktopWindows(false, onScreenWindowsOnly: true)

            guard let display = content.displays.first(where: {
                $0.displayID == displayID
            }) else {
                Diagnostics.previews.error(
                    "display \(displayID) not in SCShareableContent"
                )
                return nil
            }

            // Hide ourselves so the bar (if expanded) doesn't appear in the
            // screenshot.
            let ourBundleID = Bundle.main.bundleIdentifier ?? ""
            let ourApps = content.applications.filter {
                $0.bundleIdentifier == ourBundleID
            }

            let filter = SCContentFilter(
                display: display,
                excludingApplications: ourApps,
                exceptingWindows: []
            )

            let config = SCStreamConfiguration()
            config.width = Int(display.width)
            config.height = Int(display.height)
            config.showsCursor = false
            config.capturesAudio = false

            let cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )

            let size = NSSize(width: CGFloat(display.width),
                              height: CGFloat(display.height))
            let image = NSImage(cgImage: cgImage, size: size)
            image.cacheMode = .never
            Diagnostics.previews.info(
                "captured display \(displayID) at \(Int(size.width))x\(Int(size.height))"
            )
            return image
        } catch {
            Diagnostics.previews.error(
                "SCScreenshotManager.captureImage failed: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }
}
