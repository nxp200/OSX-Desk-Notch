//
//  NotchBarView.swift
//

import SwiftUI

struct NotchBarView: View {

    @ObservedObject var spaces: SpacesObserver
    let onSelect: (Space) -> Void

    @Environment(\.notchWidth) private var notchWidth

    var body: some View {
        VStack {
            content
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(barBackground)
                .clipShape(
                    RoundedRectangle(cornerRadius: Theme.barCornerRadius,
                                     style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.barCornerRadius,
                                     style: .continuous)
                        .stroke(Theme.barStroke, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 6)
                .padding(.top, 4)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot = spaces.current, !snapshot.userSpaces.isEmpty {
            HStack(spacing: Theme.tileSpacing) {
                ForEach(snapshot.userSpaces) { space in
                    SpaceTileView(
                        space: space,
                        isCurrent: snapshot.currentSpaceID == space.id
                    ) {
                        onSelect(space)
                    }
                }
            }
        } else {
            Text("No desktops found")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.labelColor)
                .padding(.horizontal, 4)
                .frame(height: Theme.tileSize.height)
        }
    }

    private var barBackground: some View {
        ZStack {
            Theme.barBackground
            // Subtle vertical highlight on the top edge so the bar visually
            // "drops" out of the notch.
            LinearGradient(
                colors: [Color.white.opacity(0.06), .clear],
                startPoint: .top,
                endPoint: .center
            )
        }
    }
}
