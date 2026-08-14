//
//  SidebarNavigationTests.swift
//  DMGplayerTests
//

import XCTest
@testable import DMGplayer

final class SidebarNavigationTests: XCTestCase {
    func testPrimarySidebarItemsMapToTheirMatchingSelections() {
        XCTAssertEqual(SidebarPrimaryItem.diskImage.selection, .diskImage)
        XCTAssertEqual(SidebarPrimaryItem.preflight.selection, .preflight)
        XCTAssertNotEqual(
            SidebarPrimaryItem.diskImage.selection,
            SidebarPrimaryItem.preflight.selection
        )
    }
}
