import XCTest

@testable import DMGplayer

final class BackgroundImageLayoutTests: XCTestCase {
    func testAspectFillAtOneHundredPercent() {
        let rect = BackgroundImageLayout.drawRect(
            canvasSize: CGSize(width: 600, height: 360),
            imageSize: CGSize(width: 600, height: 600),
            zoom: 1
        )

        XCTAssertEqual(rect, CGRect(x: 0, y: -120, width: 600, height: 600))
    }

    func testZoomChangesSizeAroundTheCanvasCenter() {
        let smaller = BackgroundImageLayout.drawRect(
            canvasSize: CGSize(width: 600, height: 360),
            imageSize: CGSize(width: 600, height: 600),
            zoom: 0.5
        )
        let larger = BackgroundImageLayout.drawRect(
            canvasSize: CGSize(width: 600, height: 360),
            imageSize: CGSize(width: 600, height: 600),
            zoom: 2
        )

        XCTAssertEqual(smaller, CGRect(x: 150, y: 30, width: 300, height: 300))
        XCTAssertEqual(larger, CGRect(x: -300, y: -420, width: 1200, height: 1200))
    }

    func testZoomIsClampedToTheSupportedSliderRange() {
        XCTAssertEqual(BackgroundImageLayout.clampedZoom(0.1), 0.5)
        XCTAssertEqual(BackgroundImageLayout.clampedZoom(4), 2)
    }
}
