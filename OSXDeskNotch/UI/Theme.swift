//
//  Theme.swift
//

import SwiftUI

enum Theme {
    static let barCornerRadius: CGFloat = 18
    static let barBackground = Color.black.opacity(0.78)
    static let barStroke = Color.white.opacity(0.06)

    static let tileSize = CGSize(width: 56, height: 40)
    static let tileSpacing: CGFloat = 8
    static let tileCornerRadius: CGFloat = 8

    static let inactiveTileFill = Color.white.opacity(0.08)
    static let inactiveTileStroke = Color.white.opacity(0.12)
    static let activeTileFill = Color.accentColor.opacity(0.85)
    static let activeTileStroke = Color.white.opacity(0.35)

    static let labelColor = Color.white.opacity(0.85)
    static let activeLabelColor = Color.white

    static let hoverScale: CGFloat = 1.06
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
