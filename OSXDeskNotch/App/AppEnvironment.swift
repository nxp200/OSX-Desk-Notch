//
//  AppEnvironment.swift
//
//  Single owner of long-lived services. Constructed once in AppDelegate.
//

import Foundation

@MainActor
final class AppEnvironment {
    let spacesService: SpacesService
    let previewStore: SpacePreviewStore
    let spacesObserver: SpacesObserver
    let notchController: NotchWindowController

    init() {
        let service = SpacesService()
        let previews = SpacePreviewStore()
        let observer = SpacesObserver(service: service, previews: previews)
        self.spacesService = service
        self.previewStore = previews
        self.spacesObserver = observer
        self.notchController = NotchWindowController(spaces: observer)
    }
}
