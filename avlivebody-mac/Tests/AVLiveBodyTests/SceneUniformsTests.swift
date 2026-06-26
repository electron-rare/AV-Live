import XCTest
@testable import AVLiveBody

final class SceneUniformsTests: XCTestCase {
    func testStride() {
        XCTAssertEqual(MemoryLayout<SceneRenderer.SceneUniforms>.stride, 144)
    }
}
