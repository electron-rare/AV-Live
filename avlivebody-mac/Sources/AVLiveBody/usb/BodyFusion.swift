import AVLiveWire
import Foundation
import simd

/// Associates Multi-HMR meshes with USB skeletons and corrects the
/// mesh pelvis depth. Pure, stateless — unit-testable.
enum BodyFusion {
    static let pelvisJoint = 0

    static func fuse(persons: [MultiHMRPerson],
                     skeletons: [Int: SkeletonPayload])
        -> [MultiHMRPerson] {
        let pelvisZs: [Float] = skeletons.values.compactMap { s in
            guard pelvisJoint < s.valid.count,
                  s.valid[pelvisJoint] else { return nil }
            return s.joints[pelvisJoint].z
        }
        guard !pelvisZs.isEmpty,
              let primaryIdx = persons.indices.max(by: {
                  persons[$0].score < persons[$1].score
              }) else { return persons }
        var out = persons
        out[primaryIdx].translation.z = pelvisZs[0]
        return out
    }
}
