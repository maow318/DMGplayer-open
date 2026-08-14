import Foundation
import XCTest

@testable import DMGplayer

final class SnapEngineTests: XCTestCase {
    func testSnapsToCanvasCenterAndThirds() {
        let center = SnapEngine.snap(
            proposedCenter: CGPoint(x: 302, y: 178),
            movingSize: CGSize(width: 96, height: 96),
            otherObjects: [],
            canvasSize: CGSize(width: 600, height: 360)
        )
        XCTAssertEqual(center.point, CGPoint(x: 300, y: 180))
        XCTAssertEqual(Set(center.guides.map(\.reason)), ["窗口居中"])

        let thirds = SnapEngine.snap(
            proposedCenter: CGPoint(x: 198, y: 122),
            movingSize: CGSize(width: 20, height: 20),
            otherObjects: [],
            canvasSize: CGSize(width: 600, height: 360)
        )
        XCTAssertEqual(thirds.point, CGPoint(x: 200, y: 120))
    }

    func testSnapsToSiblingCenterEdgeAndEqualSpacing() {
        let objects = [
            SnapObject(id: UUID(), center: CGPoint(x: 100, y: 100), size: CGSize(width: 40, height: 40)),
            SnapObject(id: UUID(), center: CGPoint(x: 200, y: 100), size: CGSize(width: 40, height: 40)),
        ]
        let equal = SnapEngine.snap(
            proposedCenter: CGPoint(x: 299, y: 102),
            movingSize: CGSize(width: 40, height: 40),
            otherObjects: objects,
            canvasSize: CGSize(width: 640, height: 400)
        )
        XCTAssertEqual(equal.point, CGPoint(x: 300, y: 100))
        XCTAssertTrue(equal.guides.contains { $0.reason == "相同间距" })

        let edge = SnapEngine.snap(
            proposedCenter: CGPoint(x: 211, y: 160),
            movingSize: CGSize(width: 20, height: 20),
            otherObjects: [objects[1]],
            canvasSize: CGSize(width: 640, height: 400)
        )
        XCTAssertTrue(edge.guides.contains { $0.reason == "对象边缘" })
    }

    func testOptionEquivalentDisablesSnapping() {
        let proposed = CGPoint(x: 302, y: 178)
        let result = SnapEngine.snap(
            proposedCenter: proposed,
            movingSize: CGSize(width: 96, height: 96),
            otherObjects: [],
            canvasSize: CGSize(width: 600, height: 360),
            isEnabled: false
        )
        XCTAssertEqual(result.point, proposed)
        XCTAssertTrue(result.guides.isEmpty)
    }
}
