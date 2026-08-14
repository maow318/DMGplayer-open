import XCTest

@testable import DMGplayer

@MainActor
final class CanvasSelectionTests: XCTestCase {
    func testEveryCanvasObjectCanReplaceTheCurrentSelection() {
        var item = ContentItem()
        item.name = "Thunder.pkg"
        var text = TextObject()
        text.text = "将 App 拖到 Applications 文件夹"
        var image = ImageObject()
        image.imageData = Data([0])

        var project = DMGProject()
        project.items = [item]
        project.textObjects = [text]
        project.imageObjects = [image]
        let store = ProjectStore(project: project)

        store.canvasSelection = .text(text.id)
        XCTAssertEqual(store.canvasSelection, .text(text.id))

        store.canvasSelection = .item(item.id)
        XCTAssertEqual(store.canvasSelection, .item(item.id))
        XCTAssertEqual(store.sidebarSelection, .contentItem(item.id))

        store.canvasSelection = .image(image.id)
        XCTAssertEqual(store.canvasSelection, .image(image.id))
        XCTAssertEqual(store.sidebarSelection, .imageObject(image.id))
    }
}
