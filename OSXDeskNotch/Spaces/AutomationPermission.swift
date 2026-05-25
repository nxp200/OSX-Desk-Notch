//
//  AutomationPermission.swift
//
//  Wrapper around `AEDeterminePermissionToAutomateTarget` so we can query
//  the per-target Apple-Events TCC state without firing the user-visible
//  prompt. The prompt itself is triggered the first time we *use* the
//  permission (by executing an NSAppleScript), not by this query.
//

import Foundation
import ApplicationServices

@MainActor
enum AutomationPermission {

    enum Status {
        case granted
        case denied
        case notDetermined
    }

    /// System Events is the privileged helper we drive to inject the
    /// Control+Arrow keystroke. We never need any other target.
    static func statusForSystemEvents() -> Status {
        statusForBundleID("com.apple.systemevents")
    }

    static func statusForBundleID(_ bundleID: String) -> Status {
        var address = AEAddressDesc()
        let createStatus = bundleID.withCString { ptr -> OSStatus in
            AECreateDesc(
                DescType(typeApplicationBundleID),
                UnsafeRawPointer(ptr),
                bundleID.utf8.count,
                &address
            )
        }
        guard createStatus == noErr else { return .notDetermined }
        defer { AEDisposeDesc(&address) }

        // Passing `false` for `askUserIfNeeded` gives us the cached TCC
        // state without prompting.
        let status = AEDeterminePermissionToAutomateTarget(
            &address,
            typeWildCard,
            typeWildCard,
            false
        )

        switch status {
        case noErr:
            return .granted
        case -1743:                 // errAEEventNotPermitted
            return .denied
        default:
            return .notDetermined
        }
    }
}
