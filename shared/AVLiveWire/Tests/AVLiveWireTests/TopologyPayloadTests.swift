import XCTest
@testable import AVLiveWire

final class TopologyPayloadTests: XCTestCase {
    func testFrameTagTopology() {
        XCTAssertEqual(FrameTag.topology.rawValue, 7)
    }

    func testRoundTrip() {
        let names = ["root_joint", "hips_joint", "left_arm_joint"]
        let parents: [Int16] = [-1, 0, 1]
        let p = TopologyPayload(jointNames: names, parents: parents)
        let r = TopologyPayload(decoding: p.encoded())
        XCTAssertNotNil(r)
        XCTAssertEqual(r!.jointNames, names)
        XCTAssertEqual(r!.parents, parents)
    }

    func testRejectsTruncated() {
        // Claims 3 joints but provides no body.
        let bytes: [UInt8] = [0x00, 0x03]
        XCTAssertNil(TopologyPayload(decoding: Data(bytes)))
    }

    func testEmpty() {
        let p = TopologyPayload(jointNames: [], parents: [])
        let r = TopologyPayload(decoding: p.encoded())
        XCTAssertNotNil(r)
        XCTAssertEqual(r!.jointNames, [])
        XCTAssertEqual(r!.parents, [])
    }
}
