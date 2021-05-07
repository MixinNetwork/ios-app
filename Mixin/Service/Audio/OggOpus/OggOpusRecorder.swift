import Foundation
import AVFoundation
import MixinServices

protocol OggOpusRecorderDelegate: AnyObject {
    func oggOpusRecorderIsWaitingForActivation(_ recorder: OggOpusRecorder)
    func oggOpusRecorderDidStartRecording(_ recorder: OggOpusRecorder)
    func oggOpusRecorder(_ recorder: OggOpusRecorder, didCancelRecordingForReason reason: OggOpusRecorder.CancelledReason, userInfo: [String : Any]?)
    func oggOpusRecorder(_ recorder: OggOpusRecorder, didFailRecordingWithError error: Error)
    func oggOpusRecorder(_ recorder: OggOpusRecorder, didFinishRecordingWithMetadata data: AudioMetadata)
    func oggOpusRecorderDidDetectAudioSessionInterruptionEnd(_ recorder: OggOpusRecorder)
}

fileprivate let recordingSampleRate: Int32 = 16000
fileprivate let streamFormat: AudioStreamBasicDescription = {
    let bitsPerChannel: UInt32 = 16
    let channelsPerFrame: UInt32 = 1
    let bytesPerFrame: UInt32 = (bitsPerChannel / 8) * channelsPerFrame;
    return .init(mSampleRate: Float64(recordingSampleRate),
                 mFormatID: kAudioFormatLinearPCM,
                 mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
                 mBytesPerPacket: bytesPerFrame,
                 mFramesPerPacket: 1,
                 mBytesPerFrame: bytesPerFrame,
                 mChannelsPerFrame: channelsPerFrame,
                 mBitsPerChannel: bitsPerChannel,
                 mReserved: 0)
}()

// See kAudioUnitSubType_RemoteIO
fileprivate enum RemoteIOBus {
    static let output: UInt32 = 0
    static let input: UInt32 = 1
}

final class OggOpusRecorder {
    
    enum Error: Swift.Error {
        case mediaServiceWereReset
        case missingAudioComponent
        case newAudioUnit(OSStatus)
        case disableOutput(OSStatus)
        case enableInput(OSStatus)
        case setRecordingCallback(OSStatus)
        case setStreamFormat(OSStatus)
        case initializeAudioUnit(OSStatus)
        case startAudioUnit(OSStatus)
    }
    
    enum CancelledReason: UInt {
        case audioSessionInterrupted = 0
        case audioRouteChange = 1
        case bufferEnqueueFailed = 2
        case userInitiated = 3
    }
    
    let path: String
    
    weak var delegate: OggOpusRecorderDelegate?
    
    @Synchronized(value: false)
    private(set) var isRecording: Bool
    
    private let writer: OggOpusWriter
    private let processingQueue = DispatchQueue(label: "one.mixin.messenger.OggOpusRecorder")
    private let waveformPeakSampleScope = 100
    private let numberOfWaveformIntensities = 63
    
    fileprivate var audioUnit: AudioUnit?
    
    private var retainedSelf: Unmanaged<OggOpusRecorder>?
    private var waveformSamples = Data()
    private var waveformPeak: Int16 = 0
    private var waveformPeakCount = 0
    private var numberOfEncodedSamples: UInt = 0
    private var duration: TimeInterval = 0
    private var stopAfterNumberOfPackets: Int?
    
    private weak var timer: Timer?
    
    public init(path: String) throws {
        self.path = path
        self.writer = try OggOpusWriter(path: path, inputSampleRate: recordingSampleRate)
    }
    
    deinit {
        #if DEBUG
        print("OggOpusRecroder \(Unmanaged<OggOpusRecorder>.passUnretained(self).toOpaque()) deinitialized")
        #endif
    }
    
    func record(for duration: TimeInterval) {
        if AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint {
            DispatchQueue.main.async {
                self.delegate?.oggOpusRecorderIsWaitingForActivation(self)
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
                    try session.setPreferredIOBufferDuration(0.005)
                }
            } catch {
                DispatchQueue.main.async {
                    self.delegate?.oggOpusRecorder(self, didFailRecordingWithError: error)
                }
                return
            }
            
            do {
                self.duration = duration
                self.stopAfterNumberOfPackets = nil
                try self.startRecording()
                DispatchQueue.main.async {
                    self.delegate?.oggOpusRecorderDidStartRecording(self)
                }
            } catch {
                try? AudioSession.shared.deactivate(client: self, notifyOthersOnDeactivation: true)
                DispatchQueue.main.async {
                    self.delegate?.oggOpusRecorder(self, didFailRecordingWithError: error)
                }
            }
        }
    }
    
    func stop() {
        processingQueue.async {
            let numberOfPackets = 0.1 / AVAudioSession.sharedInstance().ioBufferDuration
            self.stopAfterNumberOfPackets = Int(ceil(numberOfPackets))
        }
    }
    
    func cancel(for reason: CancelledReason, userInfo: [String : Any]? = nil) {
        processingQueue.async {
            guard self.isRecording else {
                return
            }
            self.close()
            try? FileManager.default.removeItem(atPath: self.path)
            DispatchQueue.main.async {
                self.delegate?.oggOpusRecorder(self, didCancelRecordingForReason: reason, userInfo: userInfo)
            }
        }
    }
    
}

extension OggOpusRecorder: AudioSessionClient {
    
    var priority: AudioSessionClientPriority {
        .audioRecord
    }
    
    func audioSessionDidBeganInterruption(_ audioSession: AudioSession) {
        cancel(for: .audioSessionInterrupted)
    }
    
    func audioSessionDidEndInterruption(_ audioSession: AudioSession) {
        delegate?.oggOpusRecorderDidDetectAudioSessionInterruptionEnd(self)
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
            self.delegate?.oggOpusRecorder(self, didFailRecordingWithError: Error.mediaServiceWereReset)
        }
    }
    
}

extension OggOpusRecorder {
    
    private func startRecording() throws {
        var acd = AudioComponentDescription(componentType: kAudioUnitType_Output,
                                            componentSubType: kAudioUnitSubType_RemoteIO,
                                            componentManufacturer: kAudioUnitManufacturer_Apple,
                                            componentFlags: 0,
                                            componentFlagsMask: 0)
        guard let component = AudioComponentFindNext(nil, &acd) else {
            throw Error.missingAudioComponent
        }
        
        var result = AudioComponentInstanceNew(component, &audioUnit)
        guard result == noErr, let audioUnit = audioUnit else {
            throw Error.newAudioUnit(result)
        }
        
        var disable: UInt32 = 0
        result = AudioUnitSetProperty(audioUnit,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Output,
                                      RemoteIOBus.output,
                                      &disable,
                                      UInt32(MemoryLayout<UInt32>.size))
        guard result == noErr else {
            AudioComponentInstanceDispose(audioUnit)
            throw Error.disableOutput(result)
        }
        
        var enable: UInt32 = 1
        result = AudioUnitSetProperty(audioUnit,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Input,
                                      RemoteIOBus.input,
                                      &enable,
                                      UInt32(MemoryLayout<UInt32>.size))
        guard result == noErr else {
            AudioComponentInstanceDispose(audioUnit)
            throw Error.enableInput(result)
        }
        
        result = withUnsafePointer(to: streamFormat) { (format) -> OSStatus in
            AudioUnitSetProperty(audioUnit,
                                 kAudioUnitProperty_StreamFormat,
                                 kAudioUnitScope_Output,
                                 RemoteIOBus.input,
                                 format,
                                 UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        }
        guard result == noErr else {
            AudioComponentInstanceDispose(audioUnit)
            throw Error.setStreamFormat(result)
        }
        
        let retainedSelf = Unmanaged.passRetained(self)
        let callback = AURenderCallbackStruct(inputProc: recordingCallback(_:_:_:_:_:_:),
                                              inputProcRefCon: retainedSelf.toOpaque())
        result = withUnsafePointer(to: callback) { (callback) -> OSStatus in
            AudioUnitSetProperty(audioUnit,
                                 kAudioOutputUnitProperty_SetInputCallback,
                                 kAudioUnitScope_Global,
                                 RemoteIOBus.input,
                                 callback,
                                 UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        }
        guard result == noErr else {
            AudioComponentInstanceDispose(audioUnit)
            retainedSelf.release()
            throw Error.setRecordingCallback(result)
        }
        
        result = AudioUnitInitialize(audioUnit)
        guard result == noErr else {
            AudioComponentInstanceDispose(audioUnit)
            retainedSelf.release()
            throw Error.initializeAudioUnit(result)
        }
        
        result = AudioOutputUnitStart(audioUnit)
        guard result == noErr else {
            AudioComponentInstanceDispose(audioUnit)
            retainedSelf.release()
            throw Error.startAudioUnit(result)
        }
        
        let timer = Timer(timeInterval: duration, repeats: false) { (_) in
            self.stopRecording()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        
        self.isRecording = true
        self.retainedSelf = retainedSelf
    }
    
    private func stopRecording() {
        processingQueue.async {
            guard self.isRecording else {
                return
            }
            self.close()
            let waveform = self.makeWaveform()
            let duration = self.numberOfEncodedSamples * UInt(millisecondsPerSecond) / UInt(recordingSampleRate)
            let metadata = AudioMetadata(duration: duration, waveform: waveform)
            DispatchQueue.main.async {
                self.delegate?.oggOpusRecorder(self, didFinishRecordingWithMetadata: metadata)
            }
            try? AudioSession.shared.deactivate(client: self, notifyOthersOnDeactivation: true)
        }
    }
    
    private func close() {
        self.timer?.invalidate()
        self.retainedSelf?.release()
        self.retainedSelf = nil
        if let audioUnit = self.audioUnit {
            AudioOutputUnitStop(audioUnit)
            AudioComponentInstanceDispose(audioUnit)
        }
        self.writer.close()
        self.isRecording = false
    }
    
    private func processWaveformSamples(with pcmData: Data) {
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
    
    fileprivate func process(size: Int, render: (inout AudioBufferList) -> OSStatus) -> OSStatus {
        let pcmBytes = malloc(size)!
        let buffer = AudioBuffer(mNumberChannels: 1,
                                 mDataByteSize: UInt32(size),
                                 mData: pcmBytes)
        var bufferList = AudioBufferList(mNumberBuffers: 1,
                                         mBuffers: buffer)
        let result = render(&bufferList)
        processingQueue.async { [weak self] in
            guard let self = self, self.isRecording else {
                return
            }
            if let number = self.stopAfterNumberOfPackets {
                if number > 0 {
                    self.stopAfterNumberOfPackets = number - 1
                } else {
                    self.stopRecording()
                }
            }
            let pcmData = Data(bytesNoCopy: pcmBytes,
                               count: size,
                               deallocator: .free)
            self.numberOfEncodedSamples += UInt(pcmData.count / 2)
            self.writer.write(pcmData: pcmData)
            self.processWaveformSamples(with: pcmData)
        }
        return result
    }
    
}

fileprivate func recordingCallback(
    _ inRefCon: UnsafeMutableRawPointer,
    _ ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
    _ inTimeStamp: UnsafePointer<AudioTimeStamp>,
    _ inBusNumber: UInt32,
    _ inNumberFrames: UInt32,
    _ ioData: UnsafeMutablePointer<AudioBufferList>?
) -> OSStatus {
    let recorder = Unmanaged<OggOpusRecorder>.fromOpaque(inRefCon).takeUnretainedValue()
    guard let audioUnit = recorder.audioUnit else {
        return noErr
    }
    return recorder.process(size: Int(inNumberFrames) * 2) { (bufferList) -> OSStatus in
        AudioUnitRender(audioUnit,
                        ioActionFlags,
                        inTimeStamp,
                        RemoteIOBus.input,
                        inNumberFrames,
                        &bufferList)
    }
}
