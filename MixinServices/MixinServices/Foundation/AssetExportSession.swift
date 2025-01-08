import AVFoundation

public final class AssetExportSession {
    
    public enum Status {
        case waiting
        case exporting
        case completed
        case failed
        case cancelled
    }
    
    public typealias CompletionHandler = (Status) -> Void
    
    public private(set) var status: Status = .waiting
    public private(set) var error: Error?
    public private(set) var progress: Double = 0
    
    private let asset: AVAsset
    private let outputURL: URL
    private let queue = DispatchQueue(label: "one.mixin.asset.export")
    private let shouldOptimizeForNetworkUse = true
    private let maxOutputSize = CGSize(width: 1280, height: 720)
    private let maxBitRate: Float = 4_000_000
    private let audioSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVNumberOfChannelsKey: 2,
        AVSampleRateKey: 44100,
        AVEncoderBitRateKey: 128000
    ]
    
    private var completionHandler: CompletionHandler?
    private var reader: AVAssetReader!
    private var writer: AVAssetWriter!
    private var duration: TimeInterval = 0
    private var videoOutput: AVAssetReaderVideoCompositionOutput?
    private var videoInput: AVAssetWriterInput!
    private var audioOutput: AVAssetReaderAudioMixOutput?
    private var audioInput: AVAssetWriterInput!
    
    public init(asset: AVAsset, outputURL: URL) {
        self.asset = asset
        self.outputURL = outputURL
    }
    
    public func exportAsynchronously(
        onSizeAdjusted: @escaping @MainActor (CGSize) -> Void,
        completionHandler handler: @escaping CompletionHandler
    ) {
        guard status == .waiting else {
            assertionFailure("Session started multiple times")
            return
        }
        self.status = .exporting
        self.completionHandler = handler
        Task {
            do {
                try await self.start(onSizeAdjusted: onSizeAdjusted)
            } catch {
                self.error = error
                status = .failed
                handler(.failed)
            }
        }
    }
    
    private func start(onSizeAdjusted: @escaping @MainActor (CGSize) -> Void) async throws {
        let assetDuration = try await asset.load(.duration)
        
        reader = try AVAssetReader(asset: asset)
        writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        writer.shouldOptimizeForNetworkUse = shouldOptimizeForNetworkUse
        duration = CMTimeGetSeconds(assetDuration)
        
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        if let track = videoTracks.first {
            let (nominalFrameRate, estimatedDataRate) = try await track.load(.nominalFrameRate, .estimatedDataRate)
            var (naturalSize, transform) = try await track.load(.naturalSize, .preferredTransform)
            
            var videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: min(maxBitRate, estimatedDataRate),
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel
                ]
            ]
            
            let composition = AVMutableVideoComposition()
            let frameRate: Int32 = if nominalFrameRate != 0 {
                CMTimeScale(round(nominalFrameRate))
            } else {
                30
            }
            composition.frameDuration = CMTime(value: 1, timescale: frameRate)
            
            let rotation = atan2(transform.b, transform.a)
            if transform.tx < 0 && abs(transform.tx) != abs(naturalSize.width) && abs(transform.tx) != abs(naturalSize.height) {
                transform.tx = 0
            } else if transform.ty < 0 && abs(transform.ty) != abs(naturalSize.width) && abs(transform.ty) != abs(naturalSize.height) {
                transform.ty = 0
            } else {
                if abs(rotation - .pi / 2) < .ulpOfOne {
                    if abs(transform.tx) < .ulpOfOne {
                        transform.tx = naturalSize.height
                    }
                } else if abs(rotation + .pi / 2) < .ulpOfOne {
                    if abs(transform.ty) < .ulpOfOne {
                        transform.ty = naturalSize.width
                    }
                } else if abs(rotation - .pi) < .ulpOfOne {
                    if abs(transform.tx) < .ulpOfOne {
                        transform.tx = naturalSize.width
                    }
                    if abs(transform.ty) < .ulpOfOne {
                        transform.ty = naturalSize.height
                    }
                }
            }
            
            if abs(rotation - .pi / 2) < .ulpOfOne || abs(rotation + .pi / 2) < .ulpOfOne {
                swap(&naturalSize.width, &naturalSize.height)
            }
            
            composition.renderSize = naturalSize
            
            let longSideRatio = max(maxOutputSize.width, maxOutputSize.height) / max(naturalSize.width, naturalSize.height)
            let shortSideRatio = min(maxOutputSize.width, maxOutputSize.height) / min(naturalSize.width, naturalSize.height)
            let adjustedSize: CGSize
            if longSideRatio < 1 || shortSideRatio < 1 {
                let ratio = min(longSideRatio, shortSideRatio)
                adjustedSize = CGSize(width: round(naturalSize.width * ratio),
                                      height: round(naturalSize.height * ratio))
                await MainActor.run {
                    onSizeAdjusted(adjustedSize)
                }
            } else {
                adjustedSize = naturalSize
            }
            videoSettings[AVVideoWidthKey] = adjustedSize.width
            videoSettings[AVVideoHeightKey] = adjustedSize.height
            
            let xRatio = adjustedSize.width / naturalSize.width
            let yRatio = adjustedSize.height / naturalSize.height
            let ratio = min(xRatio, yRatio)
            let offset = CGPoint(x: (adjustedSize.width - naturalSize.width * ratio) / 2,
                                 y: (adjustedSize.height - naturalSize.height * ratio) / 2)
            var matrix = CGAffineTransform(translationX: offset.x / xRatio, y: offset.y / yRatio)
            matrix = matrix.scaledBy(x: ratio / xRatio, y: ratio / yRatio)
            transform = transform.concatenating(matrix)
            
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
            layerInstruction.setTransform(transform, at: .zero)
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: .zero, duration: assetDuration)
            instruction.layerInstructions = [layerInstruction]
            composition.instructions = [instruction]
            
            // Video output
            let videoOutput = AVAssetReaderVideoCompositionOutput(videoTracks: videoTracks, videoSettings: nil)
            videoOutput.alwaysCopiesSampleData = false
            videoOutput.videoComposition = composition
            if reader.canAdd(videoOutput) {
                reader.add(videoOutput)
            }
            self.videoOutput = videoOutput
            // Video input
            videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput.expectsMediaDataInRealTime = false
            if writer.canAdd(videoInput) {
                writer.add(videoInput)
            }
        }
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        if let track = audioTracks.first {
            // Audio output
            let audioOutput = AVAssetReaderAudioMixOutput(audioTracks: [track], audioSettings: nil)
            audioOutput.alwaysCopiesSampleData = false
            if reader.canAdd(audioOutput) {
                reader.add(audioOutput)
            }
            self.audioOutput = audioOutput
            // Audio input
            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput.expectsMediaDataInRealTime = false
            if writer.canAdd(audioInput) {
                writer.add(audioInput)
            }
        }
        
        writer.startWriting()
        reader.startReading()
        writer.startSession(atSourceTime: .zero)
        status = .exporting
        
        var videoCompleted = false
        var audioCompleted = false
        if let videoOutput = videoOutput {
            videoInput?.requestMediaDataWhenReady(on: queue, using: {
                if !self.encodeSamples(from: videoOutput, to: self.videoInput) {
                    videoCompleted = true
                    if audioCompleted {
                        self.finish()
                    }
                }
            })
        } else {
            videoCompleted = true
        }
        if let audioOutput = audioOutput {
            audioInput.requestMediaDataWhenReady(on: queue, using: {
                if !self.encodeSamples(from: audioOutput, to: self.audioInput) {
                    audioCompleted = true
                    if videoCompleted {
                        self.finish()
                    }
                }
            })
        } else {
            audioCompleted = true
        }
    }
    
    private func encodeSamples(from output: AVAssetReaderOutput, to input: AVAssetWriterInput) -> Bool {
        while input.isReadyForMoreMediaData {
            if let buffer = output.copyNextSampleBuffer() {
                var error = false
                if reader.status != .reading || writer.status != .writing {
                    error = true
                }
                if output == videoOutput {
                    var presentationTime = CMSampleBufferGetPresentationTimeStamp(buffer)
                    presentationTime = CMTimeSubtract(presentationTime, .zero)
                    progress = (duration == 0) ? 1 : CMTimeGetSeconds(presentationTime) / duration
                }
                error = !input.append(buffer)
                if error {
                    return false
                }
            } else {
                input.markAsFinished()
                return false
            }
        }
        return true
    }
    
    private func finish() {
        guard reader.status != .cancelled && writer.status != .cancelled else {
            return
        }
        if writer.status == .failed {
            Logger.general.debug(category: "AssetExportSession", message: "Writer: \(writer.error)")
            complete()
        } else if reader.status == .failed {
            Logger.general.debug(category: "AssetExportSession", message: "Reader: \(reader.error)")
            writer.cancelWriting()
            complete()
        } else {
            writer.finishWriting(completionHandler: complete)
        }
    }
    
    private func complete() {
        if writer.status == .failed || writer.status == .cancelled {
            do {
                try FileManager.default.removeItem(at: outputURL)
                Logger.general.debug(category: "AssetExportSession", message: "Deleted \(outputURL)")
            } catch {
                Logger.general.debug(category: "AssetExportSession", message: "Removing: \(error)")
            }
            status = .failed
        } else {
            Logger.general.debug(category: "AssetExportSession", message: "Success")
            status = .completed
        }
        completionHandler?(status)
        completionHandler = nil
    }
    
}
