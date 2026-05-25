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

    /// Rectangle for the expanded hover bar, sized to actual content and
    /// centred under the notch.
    let barRect: CGRect

    /// Rectangle of the screen this geometry was computed for.
    let screenFrame: CGRect

    /// Geometry for the notch + a closed bar (zero tile count). Use this
    /// for the initial hover hot-zone before any space data is loaded.
    static func compute(for screen: NSScreen) -> NotchGeometry? {
        compute(for: screen, tileCount: 0)
    }

    /// Geometry sized for the supplied number of tiles. Returns nil for
    /// screens without a notch.
    static func compute(for screen: NSScreen,
                        tileCount: Int) -> NotchGeometry? {
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

        let notchTop = screenFrame.maxY
        let notchBottom = notchTop - menuBarHeight
        let notchRect = CGRect(
            x: leftEdge,
            y: notchBottom,
            width: max(0, rightEdge - leftEdge),
            height: menuBarHeight
        )

        // Bar: sized to content (or matches notch width if no tiles yet).
        let contentWidth = tileCount > 0
            ? Theme.barWidth(forTileCount: tileCount)
            : notchRect.width
        let barWidth = max(contentWidth, notchRect.width)
        let barHeight = Theme.barTotalHeight
        let barX = notchRect.midX - barWidth / 2
        let barY = notchBottom - barHeight
        let barRect = CGRect(x: barX, y: barY,
                             width: barWidth, height: barHeight)

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
