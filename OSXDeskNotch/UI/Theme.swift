//
//  Theme.swift
//

import SwiftUI

enum Theme {
    static let barCornerRadius: CGFloat = 20
    static let barBackground = Color.black.opacity(0.82)
    static let barStroke = Color.white.opacity(0.06)

    /// Tile aspect roughly matches a MacBook Pro display (≈1.55:1).
    static let tileSize = CGSize(width: 104, height: 66)
    static let tileSpacing: CGFloat = 10
    static let tileCornerRadius: CGFloat = 10

    /// Padding inside the rounded bar around the tile row.
    static let barInnerPaddingH: CGFloat = 14
    static let barInnerPaddingV: CGFloat = 12

    /// Gap between the menu bar and the top edge of the floating bar.
    static let barTopMargin: CGFloat = 6

    static let inactiveTileFill = Color.white.opacity(0.06)
    static let inactiveTileStroke = Color.white.opacity(0.14)
    static let activeTileStroke = Color.accentColor
    static let activeTileStrokeWidth: CGFloat = 2

    static let labelColor = Color.white.opacity(0.92)
    static let labelShadow = Color.black.opacity(0.55)

    static let hoverScale: CGFloat = 1.05

    /// Returns the width of the bar (rounded rect) for a given tile count.
    static func barWidth(forTileCount n: Int) -> CGFloat {
        guard n > 0 else { return tileSize.width + barInnerPaddingH * 2 }
        let tiles = CGFloat(n) * tileSize.width
        let gaps = CGFloat(n - 1) * tileSpacing
        return tiles + gaps + barInnerPaddingH * 2
    }

    /// Total bar height including the small top margin under the notch.
    static var barTotalHeight: CGFloat {
        tileSize.height + barInnerPaddingV * 2 + barTopMargin
    }
}

private struct NotchWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = 200
}

extension EnvironmentValues {
    /// Width of the physical notch — used by the bar to position itself.
    var notchWidth: CGFloat {
        get { self[NotchWidthKey.self] }
        set { self[NotchWidthKey.self] = newValue }
    }
}
