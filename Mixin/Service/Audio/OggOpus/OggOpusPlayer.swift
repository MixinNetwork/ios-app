import Foundation
import AVFoundation
import MixinServices

fileprivate let audioQueueBufferSize: Int32 = 11520; // Should be smaller than AudioQueueBufferRef.mAudioDataByteSize

final class OggOpusPlayer {
    
    enum Error: Swift.Error {
        case newOutput
        case allocateBuffers
        case addPropertyListener
        case stop
        case cancelled
    }
    
    enum Status {
        case stopped
        case playing
        case paused
    }
    
    var onStatusChanged: ((OggOpusPlayer) -> Void)?
    
    var currentTime: Float64 {
        assert(Queue.main.isCurrent)
        var timeStamp = AudioTimeStamp()
        let status = AudioQueueGetCurrentTime(audioQueue, nil, &timeStamp, nil)
        if status == noErr {
            return timeStamp.mSampleTime / sampleRate
        } else {
            return 0
        }
    }
    
    fileprivate let reader: OggOpusReader
    
    @Synchronized(value: .stopped)
    fileprivate(set) var status: Status {
        didSet {
            self.onStatusChanged?(self)
        }
    }
    
    fileprivate var audioQueue: AudioQueueRef!
    
    private let sampleRate: Float64 = 48000
    private let numberOfBuffers = 3
    
    private var buffers = [AudioQueueBufferRef]()
    
    private lazy var format: AudioStreamBasicDescription = {
        let mBitsPerChannel: UInt32 = 16
        let mChannelsPerFrame: UInt32 = 1
        let mBytesPerFrame = (mBitsPerChannel / 8) * mChannelsPerFrame
        let mFramesPerPacket: UInt32 = 1
        let mBytesPerPacket: UInt32 = mFramesPerPacket * mBytesPerFrame
        let format = AudioStreamBasicDescription(mSampleRate: sampleRate,
                                                 mFormatID: kAudioFormatLinearPCM,
                                                 mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
                                                 mBytesPerPacket: mBytesPerPacket,
                                                 mFramesPerPacket: mFramesPerPacket,
                                                 mBytesPerFrame: mBytesPerFrame,
                                                 mChannelsPerFrame: mChannelsPerFrame,
                                                 mBitsPerChannel: mBitsPerChannel,
                                                 mReserved: 0)
        return format
    }()
    
    private var selfAsRawPointer: UnsafeMutableRawPointer {
        Unmanaged.passUnretained(self).toOpaque()
    }
    
    init(path: String) throws {
        reader = try OggOpusReader(fileAtPath: path)
        
        var status: OSStatus = noErr
        
        var audioQueue: AudioQueueRef!
        status = AudioQueueNewOutput(&format,
                                     bufferCallback,
                                     selfAsRawPointer,
                                     CFRunLoopGetMain(),
                                     CFRunLoopMode.commonModes.rawValue,
                                     0,
                                     &audioQueue)
        guard status == noErr, let audioQueue = audioQueue else {
            throw Error.newOutput
        }
        
        status = AudioQueueAddPropertyListener(audioQueue,
                                               kAudioQueueProperty_IsRunning,
                                               runningChangedCallback(_:_:_:),
                                               selfAsRawPointer)
        guard status == noErr else {
            throw Error.addPropertyListener
        }
        
        self.audioQueue = audioQueue
        
        buffers.reserveCapacity(numberOfBuffers)
        for _ in 0..<numberOfBuffers {
            var buffer: AudioQueueBufferRef!
            status = AudioQueueAllocateBuffer(audioQueue, UInt32(audioQueueBufferSize), &buffer)
            guard status == noErr else {
                dispose()
                throw Error.allocateBuffers
            }
            buffers.append(buffer)
        }
        
        AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume, 1)
    }
    
    deinit {
        if status == .playing || status == .paused {
            stop()
        }
        dispose()
        #if DEBUG
        print("OggOpusPlayer \(Unmanaged<OggOpusPlayer>.passUnretained(self).toOpaque()) deinitialized")
        #endif
    }
    
    func play() {
        assert(Queue.main.isCurrent)
        switch status {
        case .stopped:
            status = .playing
            for i in 0..<numberOfBuffers {
                bufferCallback(inUserData: selfAsRawPointer, inAQ: audioQueue, inBuffer: buffers[i])
            }
            AudioQueueStart(audioQueue, nil)
        case .playing:
            break
        case .paused:
            status = .playing
            AudioQueueStart(audioQueue, nil)
        }
    }
    
    func pause() {
        assert(Queue.main.isCurrent)
        guard status == .playing else {
            return
        }
        AudioQueuePause(audioQueue)
        status = .paused
    }
    
    func stop() {
        assert(Queue.main.isCurrent)
        guard status != .stopped else {
            return
        }
        AudioQueueStop(audioQueue, true)
        status = .stopped
    }
    
    func dispose() {
        assert(Queue.main.isCurrent)
        if let audioQueue = audioQueue {
            AudioQueueDispose(audioQueue, true)
        }
    }
    
}

fileprivate func bufferCallback(
    inUserData: UnsafeMutableRawPointer?,
    inAQ: AudioQueueRef,
    inBuffer: AudioQueueBufferRef
) {
    guard let ptr = inUserData else {
        return
    }
    let player = Unmanaged<OggOpusPlayer>.fromOpaque(ptr).takeUnretainedValue()
    guard player.status == .playing else {
        return
    }
    if let pcmData = try? player.reader.pcmData(maxLength: audioQueueBufferSize), pcmData.count > 0 {
        inBuffer.pointee.mAudioDataByteSize = UInt32(pcmData.count)
        pcmData.copyBytes(to: inBuffer.pointee.mAudioData.assumingMemoryBound(to: Data.Element.self),
                          count: pcmData.count)
        AudioQueueEnqueueBuffer(player.audioQueue, inBuffer, 0, nil)
    } else {
        AudioQueueStop(player.audioQueue, false)
    }
}

fileprivate func runningChangedCallback(
    _ inUserData: UnsafeMutableRawPointer?,
    _ inAQ: AudioQueueRef,
    _ inID: AudioQueuePropertyID
) {
    guard let ptr = inUserData else {
        return
    }
    let player = Unmanaged<OggOpusPlayer>.fromOpaque(ptr).takeUnretainedValue()
    if player.reader.didReachEnd {
        player.status = .stopped
    }
}
