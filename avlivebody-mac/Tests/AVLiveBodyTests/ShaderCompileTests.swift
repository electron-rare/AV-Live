// avlivebody-mac/Tests/AVLiveBodyTests/ShaderCompileTests.swift
import XCTest
import Metal
@testable import AVLiveBody

final class ShaderCompileTests: XCTestCase {
    func testSceneMetalCompiles() throws {
        let here = URL(fileURLWithPath: #filePath)   // .../Tests/AVLiveBodyTests/ShaderCompileTests.swift
        let shader = here
            .deletingLastPathComponent()             // AVLiveBodyTests
            .deletingLastPathComponent()             // Tests
            .deletingLastPathComponent()             // avlivebody-mac
            .appendingPathComponent("Sources/AVLiveBody/Resources/scene.metal")
        let src = try String(contentsOf: shader, encoding: .utf8)
        guard let dev = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("no Metal device")
        }
        let lib = try dev.makeLibrary(source: src, options: MTLCompileOptions())
        XCTAssertNotNil(lib.makeFunction(name: "bg_vertex"))
        XCTAssertNotNil(lib.makeFunction(name: "bg_fragment"))
    }
}
