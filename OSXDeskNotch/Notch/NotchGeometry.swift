//
//  NotchGeometry.swift
//
//  Pure math: computes the rectangle of the camera notch and the rectangle
//  where the hover bar should appear. No AppKit side effects.
//

import AppKit
import CoreGraphics

struct NotchGeometry: Equatable {
    /// Rectangle of the physical notch in global screen coordinates
    /// (origin at bottom-left of the primary display, AppKit conventions).
    let notchRect: CGRect

    /// Suggested rectangle for the expanded hover bar — a strip directly
    /// under the notch, slightly wider than the notch itself.
    let barRect: CGRect

    /// Rectangle of the screen this geometry was computed for.
    let screenFrame: CGRect

    /// Returns geometry for the supplied screen, or `nil` if the screen has
    /// no notch (either an external display, or an older MacBook).
    static func compute(for screen: NSScreen,
                        barHeight: CGFloat = 64,
                        barHorizontalPadding: CGFloat = 24) -> NotchGeometry? {
        let inset = screen.safeAreaInsets.top
        guard inset > 0 else { return nil }

        let screenFrame = screen.frame
        let menuBarHeight = inset

        // auxiliaryTopLeft/RightArea sit beside the notch in screen coords.
        // We use them as the authoritative left/right edges of the notch
        // and fall back to a centred 200pt rectangle if either is missing.
        let fallbackHalfWidth: CGFloat = 100
        let leftEdge: CGFloat = screen.auxiliaryTopLeftArea?.maxX
            ?? (screenFrame.midX - fallbackHalfWidth)
        let rightEdge: CGFloat = screen.auxiliaryTopRightArea?.minX
            ?? (screenFrame.midX + fallbackHalfWidth)

        // AppKit's screen coordinates put the origin at bottom-left, so the
        // top of the screen is `maxY`. The notch occupies the topmost strip.
        let notchTop = screenFrame.maxY
        let notchBottom = notchTop - menuBarHeight
        let notchRect = CGRect(
            x: leftEdge,
            y: notchBottom,
            width: max(0, rightEdge - leftEdge),
            height: menuBarHeight
        )

        // Bar sits just below the menu bar, centred under the notch, with
        // some horizontal breathing room on each side.
        let barWidth = notchRect.width + barHorizontalPadding * 2
        let barX = notchRect.midX - barWidth / 2
        let barY = notchBottom - barHeight
        let barRect = CGRect(x: barX, y: barY, width: barWidth, height: barHeight)

        return NotchGeometry(
            notchRect: notchRect,
            barRect: barRect,
            screenFrame: screenFrame
        )
    }

    /// Combined hot zone the mouse must stay inside for the bar to remain
    /// visible. Includes the notch + the bar with a small connecting strip.
    var hoverZone: CGRect {
        notchRect.union(barRect)
    }
}

extension NSScreen {
    /// True if this screen has a hardware notch (MacBook Pro 14"/16" 2021+,
    /// MacBook Air 13"/15" 2022+).
    var hasNotch: Bool {
        safeAreaInsets.top > 0 && auxiliaryTopLeftArea != nil
            && auxiliaryTopRightArea != nil
    }
}
