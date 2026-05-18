import AVLiveWire
import CoreMedia
import CoreVideo
import Foundation
import VideoToolbox

/// HEVC decoder. Feed `VideoPayload`s in; receive `CVPixelBuffer`s via
/// `onFrame`. Keyframe payloads must carry the VPS/SPS/PPS parameter
/// sets prepended as 4-byte-length-prefixed NAL units (the layout the
/// iOS `VideoEncoder` emits); the decoder (re)builds its format
/// description from those.
final class VideoDecoder {
    var onFrame: ((CVPixelBuffer) -> Void)?

    private var session: VTDecompressionSession?
    private var formatDesc: CMVideoFormatDescription?

    /// Decode one access unit.
    func decode(_ payload: VideoPayload) {
        var au = payload.data
        if payload.isKeyframe {
            let (params, rest) = Self.splitParameterSets(au)
            if !params.isEmpty {
                rebuildFormat(params)
            }
            au = rest
        }
        guard let fmt = formatDesc, !au.isEmpty else { return }
        if session == nil { makeSession(fmt) }
        guard let session, let block = Self.blockBuffer(au) else {
            return
        }
        var sample: CMSampleBuffer?
        var sampleSize = au.count
        guard CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault, dataBuffer: block,
            formatDescription: fmt, sampleCount: 1,
            sampleTimingEntryCount: 0, sampleTimingArray: nil,
            sampleSizeEntryCount: 1, sampleSizeArray: &sampleSize,
            sampleBufferOut: &sample) == noErr, let sample else {
            return
        }
        VTDecompressionSessionDecodeFrame(
            session, sampleBuffer: sample, flags: [],
            infoFlagsOut: nil) { [weak self] status, _, image, _, _ in
                guard status == noErr, let image else { return }
                self?.onFrame?(image)
            }
    }

    func stop() {
        if let session { VTDecompressionSessionInvalidate(session) }
        session = nil
        formatDesc = nil
    }

    deinit { stop() }

    // MARK: - Helpers

    /// Leading 4-byte-length-prefixed NAL units of HEVC parameter-set
    /// type (VPS=32, SPS=33, PPS=34) are split from the frame data.
    /// Returns (parameterSetData, frameData).
    private static func splitParameterSets(_ data: Data)
        -> (Data, Data) {
        let bytes = [UInt8](data)
        var offset = 0
        var paramEnd = 0
        while offset + 4 <= bytes.count {
            let len = (Int(bytes[offset]) << 24)
                | (Int(bytes[offset + 1]) << 16)
                | (Int(bytes[offset + 2]) << 8)
                | Int(bytes[offset + 3])
            let nalStart = offset + 4
            guard len > 0, nalStart + len <= bytes.count else { break }
            let nalType = (Int(bytes[nalStart]) >> 1) & 0x3F
            if nalType == 32 || nalType == 33 || nalType == 34 {
                offset = nalStart + len
                paramEnd = offset
            } else {
                break
            }
        }
        return (data.prefix(paramEnd),
                data.suffix(from: data.startIndex
                    .advanced(by: paramEnd)))
    }

    private func rebuildFormat(_ paramData: Data) {
        var sets: [[UInt8]] = []
        let bytes = [UInt8](paramData)
        var offset = 0
        while offset + 4 <= bytes.count {
            let len = (Int(bytes[offset]) << 24)
                | (Int(bytes[offset + 1]) << 16)
                | (Int(bytes[offset + 2]) << 8)
                | Int(bytes[offset + 3])
            let start = offset + 4
            guard len > 0, start + len <= bytes.count else { break }
            sets.append(Array(bytes[start..<start + len]))
            offset = start + len
        }
        guard sets.count >= 3 else { return }
        var fmt: CMFormatDescription?
        let status = withParameterSetPointers(sets) { pBuf, sBuf in
            CMVideoFormatDescriptionCreateFromHEVCParameterSets(
                allocator: kCFAllocatorDefault,
                parameterSetCount: sets.count,
                parameterSetPointers: pBuf,
                parameterSetSizes: sBuf,
                nalUnitHeaderLength: 4, extensions: nil,
                formatDescriptionOut: &fmt)
        }
        if status == noErr, let fmt {
            formatDesc = fmt
            if let session { VTDecompressionSessionInvalidate(session) }
            session = nil
        }
    }

    /// Build the C-style parallel arrays of parameter-set pointers and
    /// sizes that `CMVideoFormatDescriptionCreateFromHEVCParameterSets`
    /// requires, keeping the backing storage alive for the call.
    private func withParameterSetPointers(
        _ sets: [[UInt8]],
        _ body: (UnsafePointer<UnsafePointer<UInt8>>,
                 UnsafePointer<Int>) -> OSStatus) -> OSStatus {
        func recurse(_ index: Int,
                     _ ptrs: inout [UnsafePointer<UInt8>],
                     _ sizes: inout [Int]) -> OSStatus {
            if index == sets.count {
                return ptrs.withUnsafeBufferPointer { pBuf in
                    sizes.withUnsafeBufferPointer { sBuf in
                        body(pBuf.baseAddress!, sBuf.baseAddress!)
                    }
                }
            }
            return sets[index].withUnsafeBufferPointer { buf in
                ptrs.append(buf.baseAddress!)
                sizes.append(buf.count)
                return recurse(index + 1, &ptrs, &sizes)
            }
        }
        var ptrs: [UnsafePointer<UInt8>] = []
        var sizes: [Int] = []
        ptrs.reserveCapacity(sets.count)
        sizes.reserveCapacity(sets.count)
        return recurse(0, &ptrs, &sizes)
    }

    private func makeSession(_ fmt: CMVideoFormatDescription) {
        let attrs: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey:
                kCVPixelFormatType_32BGRA,
        ]
        VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault, formatDescription: fmt,
            decoderSpecification: nil,
            imageBufferAttributes: attrs as CFDictionary,
            outputCallback: nil, decompressionSessionOut: &session)
    }

    private static func blockBuffer(_ data: Data) -> CMBlockBuffer? {
        var block: CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault, memoryBlock: nil,
            blockLength: data.count,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil, offsetToData: 0,
            dataLength: data.count, flags: 0,
            blockBufferOut: &block) == noErr, let block else {
            return nil
        }
        var ok = false
        data.withUnsafeBytes { raw in
            if let base = raw.baseAddress,
               CMBlockBufferReplaceDataBytes(
                with: base, blockBuffer: block,
                offsetIntoDestination: 0,
                dataLength: data.count) == noErr { ok = true }
        }
        return ok ? block : nil
    }
}
