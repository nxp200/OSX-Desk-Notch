//
//  SpacesServiceTests.swift
//
//  These tests exercise the pure model layer. The CGS SPI itself can't be
//  meaningfully unit-tested in isolation (it talks to WindowServer), so we
//  focus on the data shapes our parser produces.
//

import XCTest
@testable import OSXDeskNotch

final class SpaceModelTests: XCTestCase {

    func testUserSpacesFilter() {
        let snapshot = DisplaySpaces(
            displayUUID: "UUID-A",
            spaces: [
                Space(id: 1, ordinal: 1, kind: .user),
                Space(id: 2, ordinal: 2, kind: .fullscreen),
                Space(id: 3, ordinal: 3, kind: .user),
                Space(id: 4, ordinal: 4, kind: .other)
            ],
            currentSpaceID: 1
        )
        XCTAssertEqual(snapshot.userSpaces.map(\.id), [1, 3])
    }

    func testCurrentSpaceLookup() {
        let snapshot = DisplaySpaces(
            displayUUID: "UUID-A",
            spaces: [
                Space(id: 10, ordinal: 1, kind: .user),
                Space(id: 20, ordinal: 2, kind: .user)
            ],
            currentSpaceID: 20
        )
        XCTAssertEqual(snapshot.currentSpace?.id, 20)
    }

    func testCurrentSpaceMissingReturnsNil() {
        let snapshot = DisplaySpaces(
            displayUUID: "UUID-A",
            spaces: [Space(id: 1, ordinal: 1, kind: .user)],
            currentSpaceID: 999
        )
        XCTAssertNil(snapshot.currentSpace)
    }
}
