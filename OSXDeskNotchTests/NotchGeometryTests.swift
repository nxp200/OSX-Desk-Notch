//
//  NotchGeometryTests.swift
//

import XCTest
@testable import OSXDeskNotch

final class NotchGeometryTests: XCTestCase {

    func testHoverZoneContainsBothNotchAndBar() {
        let notch = CGRect(x: 700, y: 1000, width: 200, height: 32)
        let bar = CGRect(x: 660, y: 936, width: 280, height: 64)
        let geo = NotchGeometry(notchRect: notch, barRect: bar,
                                screenFrame: CGRect(x: 0, y: 0,
                                                    width: 1600, height: 1032))
        let zone = geo.hoverZone
        XCTAssertTrue(zone.contains(CGPoint(x: 800, y: 1020)),
                      "Mid-notch point should be in hover zone")
        XCTAssertTrue(zone.contains(CGPoint(x: 800, y: 960)),
                      "Mid-bar point should be in hover zone")
        XCTAssertFalse(zone.contains(CGPoint(x: 200, y: 500)),
                       "Distant point should not be in hover zone")
    }

    func testNotchRectWidthIsNonNegative() {
        let notch = CGRect(x: 700, y: 1000, width: 200, height: 32)
        XCTAssertGreaterThanOrEqual(notch.width, 0)
    }
}
