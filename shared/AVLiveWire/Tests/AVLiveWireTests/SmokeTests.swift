import XCTest
@testable import AVLiveWire

final class SmokeTests: XCTestCase {
    func testProtocolVersion() {
        XCTAssertEqual(AVLiveWire.protocolVersion, 1)
    }
}
