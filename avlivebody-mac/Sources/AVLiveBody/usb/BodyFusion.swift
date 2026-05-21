import AVLiveWire
import Foundation
import simd

/// Overrides the highest-scoring Multi-HMR mesh's pelvis depth with
/// the first valid USB skeleton pelvis z. Single-person assumption:
/// with multiple skeletons in the dict the source pelvis is arbitrary
/// (dict iteration order). Pure, stateless — unit-testable.
enum BodyFusion {
    /// ARSkeleton3D joint 0 = root (hips), per ARSkeletonDefinition.defaultBody3D.
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
