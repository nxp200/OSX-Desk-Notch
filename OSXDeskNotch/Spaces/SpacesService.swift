//
//  SpacesService.swift
//
//  Thin, defensively-coded wrapper around the private CGS Spaces SPI.
//
//  Everything that touches `CGSCopy*` / `CGSManagedDisplay*` is funneled
//  through this file so the rest of the codebase never sees a raw CFArray.
//  All public methods are safe to call from the main actor.
//

import AppKit
import CoreGraphics

@MainActor
protocol SpacesProviding: AnyObject {
    /// Fetches the current spaces for the display that currently owns the
    /// menu bar. Returns `nil` if the SPI gave us something we can't parse.
    func snapshot(for screen: NSScreen) -> DisplaySpaces?

    /// Switches the supplied display to the supplied space. Returns
    /// `false` if the call could not be issued (e.g. unknown display).
    @discardableResult
    func activate(spaceID: UInt64, on displayUUID: String) -> Bool
}

@MainActor
final class SpacesService: SpacesProviding {

    private let connection: CGSConnectionID

    init() {
        self.connection = CGSMainConnectionID()
    }

    func snapshot(for screen: NSScreen) -> DisplaySpaces? {
        guard let targetUUID = Self.displayUUID(for: screen) else { return nil }

        guard let rawDisplays = CGSCopyManagedDisplaySpaces(connection)
                as? [[String: Any]] else {
            return nil
        }

        guard let displayDict = rawDisplays.first(where: {
            ($0["Display Identifier"] as? String) == targetUUID
        }) else {
            return nil
        }

        guard let rawSpaces = displayDict["Spaces"] as? [[String: Any]] else {
            return nil
        }

        let spaces: [Space] = rawSpaces.enumerated().compactMap { (index, dict) in
            guard let rawID = (dict["ManagedSpaceID"] as? NSNumber)?.uint64Value
            else { return nil }
            let typeRaw = (dict["type"] as? NSNumber)?.intValue ?? 0
            let kind: Space.Kind
            switch typeRaw {
            case 0: kind = .user
            case 4: kind = .fullscreen
            default: kind = .other
            }
            return Space(id: rawID, ordinal: index + 1, kind: kind)
        }

        let current = CGSManagedDisplayGetCurrentSpace(
            connection, targetUUID as CFString
        )

        return DisplaySpaces(
            displayUUID: targetUUID,
            spaces: spaces,
            currentSpaceID: current
        )
    }

    @discardableResult
    func activate(spaceID: UInt64, on displayUUID: String) -> Bool {
        CGSManagedDisplaySetCurrentSpace(
            connection, displayUUID as CFString, spaceID
        )
        return true
    }

    /// Resolves the WindowServer display UUID for an `NSScreen`. CG returns
    /// the same UUID format that `CGSCopyManagedDisplaySpaces` keys on.
    static func displayUUID(for screen: NSScreen) -> String? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else {
            return nil
        }
        let displayID = CGDirectDisplayID(number.uint32Value)
        guard let cfUUID = CGDisplayCreateUUIDFromDisplayID(displayID)?
                .takeRetainedValue() else {
            return nil
        }
        guard let cfString = CFUUIDCreateString(nil, cfUUID) else {
            return nil
        }
        return cfString as String
    }
}
