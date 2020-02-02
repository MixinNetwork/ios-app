import Foundation
import AVFoundation

class AudioPlayer {
    
    enum Error: Swift.Error {
        case newOutput
        case allocateBuffers
        case addPropertyListener
        case stop
        case cancelled
    }
    
    enum Status {
        case playing
        case paused
        case readyToPlay
        case didReachEnd
    }
    
    var onStatusChanged: ((AudioPlayer) -> Void)?
    
    var currentTime: Float64 {
        var timeStamp = AudioTimeStamp()
        let status = AudioQueueGetCurrentTime(audioQueue, nil, &timeStamp, nil)
        if status == noErr {
            return timeStamp.mSampleTime / sampleRate
        } else {
            return 0
        }
    }
    
    fileprivate(set) var status: Status = .readyToPlay {
        didSet {
            onStatusChanged?(self)
        }
    }
    
    fileprivate let reader: MXNOggOpusReader
    fileprivate let sampleRate: Float64 = 48000
    fileprivate let numberOfBuffers = 3
    fileprivate let audioQueueBufferSize: UInt32 = 11520; // Should be smaller than AudioQueueBufferRef.mAudioDataByteSize
    
    fileprivate var buffers = [AudioQueueBufferRef]()
    fileprivate var audioQueue: AudioQueueRef!
    
    private lazy var unretainedSelf = Unmanaged.passUnretained(self).toOpaque()
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
    
    init(path: String) throws {
        reader = try MXNOggOpusReader(fileAtPath: path)
        
        var status: OSStatus = noErr
        
        var audioQueue: AudioQueueRef!
        status = AudioQueueNewOutput(&format, aqBufferCallback, unretainedSelf, nil, nil, 0, &audioQueue)
        guard status == noErr else {
            dispose()
            throw Error.newOutput
        }
        self.audioQueue = audioQueue
        
        buffers.reserveCapacity(numberOfBuffers)
        for _ in 0..<numberOfBuffers {
            var buffer: AudioQueueBufferRef!
            status = AudioQueueAllocateBuffer(audioQueue, audioQueueBufferSize, &buffer)
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
    }
    
    func play() {
        switch status {
        case .playing:
            break
        case .paused:
            status = .playing
            AudioQueueStart(audioQueue, nil)
        case .readyToPlay, .didReachEnd:
            status = .playing
            for i in 0..<numberOfBuffers {
                aqBufferCallback(inUserData: unretainedSelf, inAq: audioQueue, inBuffer: buffers[i])
            }
            AudioQueueStart(audioQueue, nil)
        }
    }
    
    func pause() {
        guard status == .playing else {
            return
        }
        AudioQueuePause(audioQueue)
        status = .paused
    }
    
    func stop() {
        AudioQueueStop(audioQueue, true)
        status = .readyToPlay
    }
    
    func dispose() {
        if let audioQueue = audioQueue {
            AudioQueueDispose(audioQueue, true)
        }
        reader.close()
    }
    
}

fileprivate func aqBufferCallback(inUserData: UnsafeMutableRawPointer?, inAq: AudioQueueRef, inBuffer: AudioQueueBufferRef) {
    guard let ptr = inUserData else {
        return
    }
    let player = Unmanaged<AudioPlayer>.fromOpaque(ptr).takeUnretainedValue()
    guard player.status != .didReachEnd else {
        return
    }
    if let pcmData = try? player.reader.pcmData(withMaxLength: UInt(player.audioQueueBufferSize)), pcmData.count > 0 {
        inBuffer.pointee.mAudioDataByteSize = UInt32(pcmData.count)
        pcmData.copyBytes(to: inBuffer.pointee.mAudioData.assumingMemoryBound(to: UInt8.self),
                          count: pcmData.count)
        AudioQueueEnqueueBuffer(player.audioQueue, inBuffer, 0, nil)
    } else {
        player.status = .didReachEnd
        AudioQueueStop(player.audioQueue, false)
    }
}
