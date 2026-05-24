//
//  AppEnvironment.swift
//
//  Single owner of long-lived services. Constructed once in AppDelegate.
//

import Foundation

@MainActor
final class AppEnvironment {
    let spacesService: SpacesService
    let spacesObserver: SpacesObserver
    let notchController: NotchWindowController

    init() {
        let service = SpacesService()
        let observer = SpacesObserver(service: service)
        self.spacesService = service
        self.spacesObserver = observer
        self.notchController = NotchWindowController(spaces: observer)
    }
}
