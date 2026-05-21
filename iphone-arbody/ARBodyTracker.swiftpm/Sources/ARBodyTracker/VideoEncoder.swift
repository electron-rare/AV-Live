import AVLiveWire
import CoreMedia
import CoreVideo
import Foundation
import VideoToolbox

/// Hardware HEVC encoder. Feed `CVPixelBuffer`s from ARKit frames in;
/// receive one `VideoPayload` per encoded access unit via `onPayload`.
/// Keyframe payloads carry the VPS/SPS/PPS parameter sets prepended,
/// each as a 4-byte big-endian length prefix followed by the NAL
/// bytes, so the Mac decoder can build its format description without
/// a side channel.
final class VideoEncoder {
    var onPayload: ((VideoPayload) -> Void)?

    private var session: VTCompressionSession?
    private let lock = NSLock()

    /// Create the compression session for a given frame size.
    func start(width: Int32, height: Int32) {
        stop()
        var s: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: width, height: height,
            codecType: kCMVideoCodecType_HEVC,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: nil,
            refcon: nil,
            compressionSessionOut: &s)
        guard status == noErr, let s else {
            NSLog("VideoEncoder: VTCompressionSessionCreate failed %d",
                  status)
            return
        }
        VTSessionSetProperty(s, key: kVTCompressionPropertyKey_RealTime,
                             value: kCFBooleanTrue)
        VTSessionSetProperty(s,
            key: kVTCompressionPropertyKey_AllowFrameReordering,
            value: kCFBooleanFalse)
        VTSessionSetProperty(s,
            key: kVTCompressionPropertyKey_MaxKeyFrameInterval,
            value: 30 as CFNumber)
        VTCompressionSessionPrepareToEncodeFrames(s)
        lock.lock(); session = s; lock.unlock()
    }

    /// Encode one frame. `pts` is the capture timestamp in seconds.
    func encode(_ pixelBuffer: CVPixelBuffer, pts: Double) {
        lock.lock(); let s = session; lock.unlock()
        guard let s else { return }
        let time = CMTime(seconds: pts, preferredTimescale: 1_000_000)
        VTCompressionSessionEncodeFrame(
            s, imageBuffer: pixelBuffer, presentationTimeStamp: time,
            duration: .invalid, frameProperties: nil,
            infoFlagsOut: nil) { [weak self] status, _, sample in
                guard status == noErr, let sample else { return }
                self?.handle(sample)
            }
    }

    func stop() {
        lock.lock(); let s = session; session = nil; lock.unlock()
        if let s {
            VTCompressionSessionInvalidate(s)
        }
    }

    deinit { stop() }

    // MARK: - Sample -> VideoPayload

    private func handle(_ sample: CMSampleBuffer) {
        let isKeyframe = !Self.notSync(sample)
        var out = Data()
        if isKeyframe,
           let fmt = CMSampleBufferGetFormatDescription(sample) {
            out.append(Self.parameterSets(fmt))
        }
        if let block = CMSampleBufferGetDataBuffer(sample) {
            var lengthOut = 0
            var ptr: UnsafeMutablePointer<Int8>?
            if CMBlockBufferGetDataPointer(
                block, atOffset: 0, lengthAtOffsetOut: nil,
                totalLengthOut: &lengthOut,
                dataPointerOut: &ptr) == noErr, let ptr {
                out.append(UnsafeBufferPointer(
                    start: UnsafeRawPointer(ptr)
                        .assumingMemoryBound(to: UInt8.self),
                    count: lengthOut))
            }
        }
        guard !out.isEmpty else { return }
        onPayload?(VideoPayload(isKeyframe: isKeyframe, data: out))
    }

    /// True if the sample is NOT a sync (key) frame.
    private static func notSync(_ sample: CMSampleBuffer) -> Bool {
        guard let arr = CMSampleBufferGetSampleAttachmentsArray(
            sample, createIfNecessary: false),
            CFArrayGetCount(arr) > 0 else { return false }
        let dict = unsafeBitCast(CFArrayGetValueAtIndex(arr, 0),
                                 to: CFDictionary.self)
        let key = Unmanaged.passUnretained(
            kCMSampleAttachmentKey_NotSync).toOpaque()
        return CFDictionaryContainsKey(dict, key)
    }

    /// Concatenate the HEVC VPS/SPS/PPS parameter sets, each as a
    /// 4-byte big-endian length prefix followed by the NAL bytes.
    private static func parameterSets(
        _ fmt: CMFormatDescription) -> Data {
        var count = 0
        CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(
            fmt, parameterSetIndex: 0, parameterSetPointerOut: nil,
            parameterSetSizeOut: nil, parameterSetCountOut: &count,
            nalUnitHeaderLengthOut: nil)
        var data = Data()
        for i in 0..<count {
            var ptr: UnsafePointer<UInt8>?
            var size = 0
            guard CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(
                fmt, parameterSetIndex: i,
                parameterSetPointerOut: &ptr,
                parameterSetSizeOut: &size,
                parameterSetCountOut: nil,
                nalUnitHeaderLengthOut: nil) == noErr,
                let ptr else { continue }
            var be = UInt32(size).bigEndian
            withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
            data.append(UnsafeBufferPointer(start: ptr, count: size))
        }
        return data
    }
}
