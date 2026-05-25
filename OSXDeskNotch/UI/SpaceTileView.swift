//
//  SpaceTileView.swift
//

import SwiftUI

struct SpaceTileView: View {

    let space: Space
    let isCurrent: Bool
    let preview: NSImage?
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            tileBody
                .frame(width: Theme.tileSize.width,
                       height: Theme.tileSize.height)
                .clipShape(
                    RoundedRectangle(cornerRadius: Theme.tileCornerRadius,
                                     style: .continuous)
                )
                .overlay(borderOverlay)
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

    // MARK: - Pieces

    @ViewBuilder
    private var tileBody: some View {
        ZStack {
            if let preview {
                Image(nsImage: preview)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: Theme.tileSize.width,
                           height: Theme.tileSize.height)
            } else {
                Theme.inactiveTileFill
            }

            // Subtle dimming so the desktop number is always legible.
            LinearGradient(
                colors: [.black.opacity(0.55), .black.opacity(0.05),
                         .black.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(preview == nil ? 0 : 0.65)

            Text("\(space.ordinal)")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.labelColor)
                .shadow(color: Theme.labelShadow, radius: 2, x: 0, y: 1)
        }
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: Theme.tileCornerRadius,
                         style: .continuous)
            .stroke(isCurrent ? Theme.activeTileStroke
                              : Theme.inactiveTileStroke,
                    lineWidth: isCurrent ? Theme.activeTileStrokeWidth : 1)
    }
}
