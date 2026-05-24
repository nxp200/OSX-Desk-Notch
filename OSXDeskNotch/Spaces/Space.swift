//
//  Space.swift
//

import Foundation

/// A single macOS Space (a.k.a. Desktop) on a particular display.
///
/// The model is intentionally minimal — only what the UI needs. The numeric
/// `CGSSpaceID` lives in `id`; everything else is presentation data.
struct Space: Identifiable, Hashable, Sendable {
    /// The opaque WindowServer identifier for this space.
    let id: UInt64

    /// The 1-based ordinal of this space within its display (the number the
    /// user sees in Mission Control).
    let ordinal: Int

    /// Whether this is a user-created desktop space or a full-screen app
    /// space. We surface user spaces in the bar and hide full-screen ones.
    let kind: Kind

    enum Kind: Sendable {
        case user
        case fullscreen
        case other
    }
}

/// A snapshot of the spaces on one display at a point in time.
struct DisplaySpaces: Hashable, Sendable {
    /// The display's WindowServer UUID string.
    let displayUUID: String
    let spaces: [Space]
    let currentSpaceID: UInt64

    var currentSpace: Space? {
        spaces.first(where: { $0.id == currentSpaceID })
    }

    var userSpaces: [Space] {
        spaces.filter { $0.kind == .user }
    }
}
