//
//  SpacesService.swift
//
//  Read-only wrapper around the private CGS Spaces SPI. We only use the
//  SPI to *enumerate* spaces — switching is done by `SpaceSwitcher` via
//  keystroke injection because the CGS switch SPI silently no-ops on
//  several Sonoma builds.
//

import AppKit
import CoreGraphics

@MainActor
protocol SpacesProviding: AnyObject {
    /// Fetches the current spaces for the supplied screen. Returns `nil`
    /// if the SPI gave us something we can't parse.
    func snapshot(for screen: NSScreen) -> DisplaySpaces?
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
            // Prefer the 64-bit identifier when present (modern macOS).
            let id64 = (dict["id64"] as? NSNumber)?.uint64Value
            let managed = (dict["ManagedSpaceID"] as? NSNumber)?.uint64Value
            guard let rawID = id64 ?? managed else { return nil }
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
