// avlivebody-mac/Tests/AVLiveBodyTests/RenderSettingsTests.swift
import XCTest
@testable import AVLiveBody

@MainActor
final class RenderSettingsTests: XCTestCase {
    func testDefaults() {
        let s = RenderSettings()
        XCTAssertTrue(s.showSkeleton)
        XCTAssertTrue(s.showMesh)
        XCTAssertTrue(s.showVideo)
        XCTAssertFalse(s.meshMetallic)
        XCTAssertEqual(s.meshRoughness, 0.6, accuracy: 1e-9)
        XCTAssertEqual(s.videoOpacity, 1.0, accuracy: 1e-9)
        XCTAssertEqual(s.keyIntensity, 4000, accuracy: 1e-9)
        XCTAssertEqual(s.fillIntensity, 1500, accuracy: 1e-9)
        XCTAssertEqual(s.rimIntensity, 2000, accuracy: 1e-9)
        XCTAssertEqual(s.fieldOfView, 55, accuracy: 1e-9)
        XCTAssertFalse(s.showPanel)
    }
}
