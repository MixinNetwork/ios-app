import Foundation
import AVFoundation

protocol AudioRecorderDelegate: class {
    func audioRecorderIsWaitingForActivation(_ recorder: AudioRecorder)
    func audioRecorderDidStartRecording(_ recorder: AudioRecorder)
    func audioRecorder(_ recorder: AudioRecorder, didCancelRecordingForReason reason: AudioRecorder.CancelledReason, userInfo: [String : Any]?)
    func audioRecorder(_ recorder: AudioRecorder, didFailRecordingWithError error: Error)
    func audioRecorder(_ recorder: AudioRecorder, didFinishRecordingWithMetadata data: AudioMetadata)
    func audioRecorderDidDetectAudioSessionInterruptionEnd(_ recorder: AudioRecorder)
}

fileprivate let bufferDuration: Double = 0.5
fileprivate let numberOfAudioQueueBuffers = 3
fileprivate let recordingSampleRate: Int32 = 16000
fileprivate let millisecondsPerSecond: UInt = 1000
fileprivate let waveformPeakSampleScope = 100
fileprivate let numberOfWaveformIntensities = 63

final class AudioRecorder {
    
    enum Error: Swift.Error {
        case audioQueueNewInput
        case audioQueueGetStreamDescription
        case audioQueueAllocateBuffer
        case audioQueueEnqueueBuffer
        case audioQueueStart
        case audioQueueGetMaximumOutputPacketSize
        case createAudioFile
        case writeAudioFile
        case mediaServiceWereReset
        case missingAudioQueue
    }
    
    enum CancelledReason: UInt {
        case audioSessionInterrupted = 0
        case audioRouteChange = 1
        case bufferEnqueueFailed = 2
        case userInitiated = 3
    }
    
    let path: String
    
    var vibratesAtBeginning = true
    
    weak var delegate: AudioRecorderDelegate?
    
    private(set) var isRecording = false
    
    fileprivate let writer: OggOpusWriter
    fileprivate let processingQueue = DispatchQueue(label: "one.mixin.messenger.AudioRecorder")
    
    fileprivate var audioQueue: AudioQueueRef?
    fileprivate var waveformSamples = Data()
    fileprivate var waveformPeak: Int16 = 0
    fileprivate var waveformPeakCount = 0
    fileprivate var numberOfEncodedSamples: UInt = 0
    
    private var duration: TimeInterval = 0
    private var buffers = [AudioQueueBufferRef?](repeating: nil, count: numberOfAudioQueueBuffers)
    
    private weak var timer: Timer?
    
    public init(path: String) throws {
        self.path = path
        self.writer = try OggOpusWriter(path: path, inputSampleRate: recordingSampleRate)
    }
    
    func record(for duration: TimeInterval) {
        if AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint {
            DispatchQueue.main.async {
                self.delegate?.audioRecorderIsWaitingForActivation(self)
            }
        }
        processingQueue.async { [weak self] in
            guard let self = self else {
                return
            }
            do {
                try AudioSession.shared.activate(client: self) { (session) in
                    try session.setCategory(.playAndRecord,
                                            mode: .default,
                                            options: [.allowBluetooth])
                    if #available(iOS 13.0, *) {
                        try session.setAllowHapticsAndSystemSoundsDuringRecording(true)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.delegate?.audioRecorder(self, didFailRecordingWithError: error)
                }
                return
            }
            
            if self.vibratesAtBeginning {
                AudioServicesPlaySystemSound(1519);
            }
            do {
                self.duration = duration
                try self.performRecording()
                DispatchQueue.main.async {
                    self.delegate?.audioRecorderDidStartRecording(self)
                }
            } catch {
                try? AudioSession.shared.deactivate(client: self, notifyOthersOnDeactivation: true)
                DispatchQueue.main.async {
                    self.delegate?.audioRecorder(self, didFailRecordingWithError: error)
                }
            }
        }
    }
    
    func stop() {
        processingQueue.async {
            guard self.isRecording else {
                return
            }
            let waveform = self.makeWaveform()
            let duration = self.numberOfEncodedSamples * millisecondsPerSecond / UInt(recordingSampleRate)
            let metadata = AudioMetadata(duration: duration, waveform: waveform)
            self.cleanUp()
            DispatchQueue.main.async {
                self.delegate?.audioRecorder(self, didFinishRecordingWithMetadata: metadata)
            }
        }
    }
    
    func cancel(for reason: CancelledReason, userInfo: [String : Any]? = nil) {
        processingQueue.async {
            guard self.isRecording else {
                return
            }
            self.cleanUp()
            try? FileManager.default.removeItem(atPath: self.path)
            DispatchQueue.main.async {
                self.delegate?.audioRecorder(self, didCancelRecordingForReason: reason, userInfo: userInfo)
            }
        }
    }
    
    fileprivate func processWaveformSamples(with pcmData: Data) {
        let numberOfSamples = pcmData.count / 2
        guard numberOfSamples > 0 else {
            return
        }
        pcmData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Void in
            let samples = ptr.bindMemory(to: Int16.self)
            for i in 0..<numberOfSamples {
                let sample = abs(samples.baseAddress!.advanced(by: i).pointee)
                waveformPeak = max(waveformPeak, sample)
                waveformPeakCount += 1
                if waveformPeakCount >= waveformPeakSampleScope {
                    withUnsafeBytes(of: waveformPeak) { (peak) -> Void in
                        let bytes = peak.bindMemory(to: UInt8.self).baseAddress!
                        waveformSamples.append(bytes, count: 2)
                    }
                    waveformPeak = 0
                    waveformPeakCount = 0
                }
            }
        }
    }
    
}

extension AudioRecorder: AudioSessionClient {
    
    var priority: AudioSessionClientPriority {
        .audioRecord
    }
    
    func audioSessionDidBeganInterruption(_ audioSession: AudioSession) {
        cancel(for: .audioSessionInterrupted)
    }
    
    func audioSessionDidEndInterruption(_ audioSession: AudioSession) {
        delegate?.audioRecorderDidDetectAudioSessionInterruptionEnd(self)
    }
 
    func audioSession(_ audioSession: AudioSession, didChangeRouteFrom previousRoute: AVAudioSessionRouteDescription, reason: AVAudioSession.RouteChangeReason) {
        let category = audioSession.avAudioSession.category
        let isCategoryAvailable = category == .record || category == .playAndRecord
        let hasInput = !audioSession.avAudioSession.currentRoute.inputs.isEmpty
        if !hasInput || !isCategoryAvailable {
            cancel(for: .audioRouteChange)
        }
    }
    
    func audioSessionMediaServicesWereReset(_ audioSession: AudioSession) {
        isRecording = false
        DispatchQueue.main.async {
            self.delegate?.audioRecorder(self, didFailRecordingWithError: Error.mediaServiceWereReset)
        }
    }
    
}

extension AudioRecorder {
    
    private func performRecording() throws {
        let bitsPerChannel: UInt32 = 16
        let channelsPerFrame: UInt32 = 1
        let bytesPerFrame: UInt32 = (bitsPerChannel / 8) * channelsPerFrame;
        var format = AudioStreamBasicDescription(mSampleRate: Float64(recordingSampleRate),
                                                 mFormatID: kAudioFormatLinearPCM,
                                                 mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
                                                 mBytesPerPacket: bytesPerFrame,
                                                 mFramesPerPacket: 1,
                                                 mBytesPerFrame: bytesPerFrame,
                                                 mChannelsPerFrame: channelsPerFrame,
                                                 mBitsPerChannel: bitsPerChannel,
                                                 mReserved: 0)
        let selfAsOpaquePointer = Unmanaged.passUnretained(self).toOpaque()
        var result = withUnsafePointer(to: format) { (format) -> OSStatus in
            AudioQueueNewInput(format, inputBufferHandler, selfAsOpaquePointer, nil, nil, 0, &audioQueue)
        }
        guard result == noErr, let audioQueue = audioQueue else {
            throw Error.audioQueueNewInput
        }
        
        var size = UInt32(MemoryLayout.size(ofValue: format))
        result = AudioQueueGetProperty(audioQueue, kAudioQueueProperty_StreamDescription, &format, &size)
        guard result == noErr else {
            throw Error.audioQueueGetStreamDescription
        }
        
        let bufferSize = try self.bufferSize(with: format, seconds: bufferDuration)
        for i in 0..<numberOfAudioQueueBuffers {
            result = AudioQueueAllocateBuffer(audioQueue, bufferSize, &buffers[i])
            guard result == noErr else {
                throw Error.audioQueueAllocateBuffer
            }
            result = AudioQueueEnqueueBuffer(audioQueue, buffers[i]!, 0, nil)
            guard result == noErr else {
                throw Error.audioQueueEnqueueBuffer
            }
        }
        
        result = AudioQueueStart(audioQueue, nil);
        guard result == noErr else {
            throw Error.audioQueueStart
        }
        
        let timer = Timer(timeInterval: duration, repeats: false, block: { (_) in
            self.stop()
        })
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        
        isRecording = true
    }
    
    private func bufferSize(with format: AudioStreamBasicDescription, seconds: Double) throws -> UInt32 {
        let bytes: UInt32
        let frames = ceil(seconds * format.mSampleRate)
        if format.mBytesPerFrame > 0 {
            bytes = UInt32(frames) * format.mBytesPerPacket
        } else {
            var maxPacketSize: UInt32 = 0
            var packets: Double
            if format.mBytesPerPacket > 0 {
                maxPacketSize = format.mBytesPerPacket
            } else if let audioQueue = audioQueue {
                var propertySize = UInt32(MemoryLayout.size(ofValue: maxPacketSize))
                let result = AudioQueueGetProperty(audioQueue, kAudioQueueProperty_MaximumOutputPacketSize, &maxPacketSize, &propertySize)
                guard result == noErr else {
                    throw Error.audioQueueGetMaximumOutputPacketSize
                }
            } else {
                throw Error.missingAudioQueue
            }
            if format.mFramesPerPacket > 0 {
                packets = frames / Double(format.mFramesPerPacket)
            } else {
                packets = frames
            }
            if packets == 0 {
                packets = 1
            }
            bytes = UInt32(packets) * maxPacketSize
        }
        return bytes
    }
    
    private func makeWaveform() -> Data {
        let intensities = malloc(numberOfWaveformIntensities)!
        memset(intensities, 0, numberOfWaveformIntensities)
        let numberOfRawSamples = waveformSamples.count / 2
        var minRawSample: Int16 = .max
        var maxRawSample: Int16 = 0
        waveformSamples.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Void in
            let rawSamples = ptr.bindMemory(to: Int16.self).baseAddress!
            for i in 0..<numberOfRawSamples {
                let sample = rawSamples.advanced(by: i).pointee
                minRawSample = min(minRawSample, sample)
                maxRawSample = max(maxRawSample, sample)
            }
            let delta = Float(UInt8.max) / Float(maxRawSample - minRawSample)
            for i in 0..<numberOfRawSamples {
                let index = i * numberOfWaveformIntensities / numberOfRawSamples
                let intensity = min(Float(UInt8.max), Float(rawSamples.advanced(by: i).pointee) * delta)
                intensities.assumingMemoryBound(to: UInt8.self).advanced(by: index).pointee = UInt8(intensity)
            }
        }
        return Data(bytesNoCopy: intensities, count: numberOfWaveformIntensities, deallocator: .free)
    }
    
    private func cleanUp() {
        isRecording = false
        timer?.invalidate()
        timer = nil
        if let audioQueue = audioQueue {
            AudioQueueStop(audioQueue, true)
            AudioQueueDispose(audioQueue, true)
        }
        writer.close()
        try? AudioSession.shared.deactivate(client: self, notifyOthersOnDeactivation: true)
    }
    
}

fileprivate func inputBufferHandler(
    _ inUserData: UnsafeMutableRawPointer!,
    _ inAQ: AudioQueueRef,
    _ inBuffer: AudioQueueBufferRef,
    _ inStartTime: UnsafePointer<AudioTimeStamp>,
    _ inNumberPacketDescriptions: UInt32,
    _ inPacketDescs: UnsafePointer<AudioStreamPacketDescription>?
) {
    let recorder = Unmanaged<AudioRecorder>.fromOpaque(inUserData).takeUnretainedValue()
    if inNumberPacketDescriptions > 0 {
        let pcmData = Data(bytes: inBuffer.pointee.mAudioData,
                           count: Int(inBuffer.pointee.mAudioDataByteSize))
        recorder.processingQueue.async { [weak recorder] in
            guard let recorder = recorder, recorder.isRecording else {
                return
            }
            recorder.numberOfEncodedSamples += UInt(pcmData.count / 2)
            recorder.writer.write(pcmData: pcmData)
            recorder.processWaveformSamples(with: pcmData)
        }
    }
    if recorder.isRecording {
        let result = AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, nil);
        if result != noErr {
            recorder.cancel(for: .bufferEnqueueFailed,
                            userInfo: ["enqueue_buffer_result": result])
        }
    }
}
