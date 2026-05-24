//
//  SpaceTileView.swift
//

import SwiftUI

struct SpaceTileView: View {

    let space: Space
    let isCurrent: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.tileCornerRadius,
                                 style: .continuous)
                    .fill(isCurrent ? Theme.activeTileFill
                                    : Theme.inactiveTileFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.tileCornerRadius,
                                         style: .continuous)
                            .stroke(isCurrent ? Theme.activeTileStroke
                                              : Theme.inactiveTileStroke,
                                    lineWidth: 1)
                    )

                Text("\(space.ordinal)")
                    .font(.system(size: 15, weight: .semibold,
                                  design: .rounded))
                    .foregroundStyle(isCurrent ? Theme.activeLabelColor
                                               : Theme.labelColor)
            }
            .frame(width: Theme.tileSize.width, height: Theme.tileSize.height)
            .scaleEffect(isHovering ? Theme.hoverScale : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7),
                       value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .accessibilityLabel("Switch to Desktop \(space.ordinal)")
        .accessibilityAddTraits(isCurrent ? [.isSelected] : [])
    }
}
