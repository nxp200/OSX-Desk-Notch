//
//  Diagnostics.swift
//
//  Centralised os.Logger access. Filter in Console.app with
//      subsystem == "com.osxdesknotch.OSXDeskNotch"
//  to see exactly what the app is doing — useful for telling apart
//  "the click didn't fire", "permission is missing", and "the keystroke
//  was sent but the system ignored it".
//

import Foundation
import os

enum Diagnostics {
    private static let subsystem = "com.osxdesknotch.OSXDeskNotch"

    static let switcher = Logger(subsystem: subsystem, category: "switcher")
    static let previews = Logger(subsystem: subsystem, category: "previews")
    static let permissions = Logger(subsystem: subsystem, category: "permissions")
}
