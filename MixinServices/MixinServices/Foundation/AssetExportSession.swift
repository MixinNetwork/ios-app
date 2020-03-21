import AVFoundation

public class AssetExportSession {

    public typealias CompletionHandler = () -> Void

    public enum Status {
        case unknown
        case waiting
        case exporting
        case completed
        case failed
        case cancelled
    }

    let asset: AVAsset
    let outputURL: URL
    let fileType = AVFileType.mp4
    let timeRange = CMTimeRange(start: .zero, end: .positiveInfinity)
    let shouldOptimizeForNetworkUse = true

    private let videoSettings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: 1280,
        AVVideoHeightKey: 720,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 1500000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel
        ]
    ]
    private let audioSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVNumberOfChannelsKey: 2,
        AVSampleRateKey: 44100,
        AVEncoderBitRateKey: 128000
    ]


    public private(set) var status = Status.unknown
    public private(set) var error: Error?
    public private(set) var progress: Double = 0

    private let queue = DispatchQueue(label: "one.mixin.asset.export")
    private let epsilon = CGFloat(Double.ulpOfOne)

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

    public func exportAsynchronously(completionHandler handler: @escaping CompletionHandler) {
        status = .waiting
        self.completionHandler = handler
        do {
            reader = try AVAssetReader(asset: asset)
            reader.timeRange = timeRange
            writer = try AVAssetWriter(outputURL: outputURL, fileType: fileType)
            writer.shouldOptimizeForNetworkUse = shouldOptimizeForNetworkUse
            let videoTracks = asset.tracks(withMediaType: .video)
            if timeRange.duration.isValid && !timeRange.duration.isPositiveInfinity {
                duration = CMTimeGetSeconds(timeRange.duration)
            } else {
                duration = CMTimeGetSeconds(asset.duration)
            }
            var sizeAdjustedVideoSettings = videoSettings
            if let track = videoTracks.first {
                let composition = AVMutableVideoComposition()
                let frameRate: Int32
                if track.nominalFrameRate != 0 {
                    frameRate = CMTimeScale(round(track.nominalFrameRate))
                } else {
                    frameRate = 30
                }
                composition.frameDuration = CMTime(value: 1, timescale: frameRate)

                var naturalSize = track.naturalSize
                var transform = track.preferredTransform

                let rotation = atan2(transform.b, transform.a)
                if transform.tx < 0 && abs(transform.tx) != abs(naturalSize.width) && abs(transform.tx) != abs(naturalSize.height) {
                    transform.tx = 0
                } else if transform.ty < 0 && abs(transform.ty) != abs(naturalSize.width) && abs(transform.ty) != abs(naturalSize.height) {
                    transform.ty = 0
                } else {
                    if abs(rotation - .pi / 2) < epsilon {
                        if abs(transform.tx) < epsilon {
                            transform.tx = naturalSize.height
                        }
                    } else if abs(rotation + .pi / 2) < epsilon {
                        if abs(transform.ty) < epsilon {
                            transform.ty = naturalSize.width
                        }
                    } else if abs(rotation - .pi) < epsilon {
                        if abs(transform.tx) < epsilon {
                            transform.tx = naturalSize.width
                        }
                        if abs(transform.ty) < epsilon {
                            transform.ty = naturalSize.height
                        }
                    }
                }

                if abs(rotation - .pi / 2) < epsilon || abs(rotation + .pi / 2) < epsilon {
                    swap(&naturalSize.width, &naturalSize.height)
                }

                composition.renderSize = naturalSize

                let targetWidth = CGFloat((videoSettings[AVVideoWidthKey] as! NSNumber).floatValue)
                let targetHeight = CGFloat((videoSettings[AVVideoHeightKey] as! NSNumber).floatValue)
                let longSideRatio = max(targetWidth, targetHeight) / max(naturalSize.width, naturalSize.height)
                let shortSideRatio = min(targetWidth, targetHeight) / min(naturalSize.width, naturalSize.height)
                let targetSize: CGSize
                if longSideRatio < 1 || shortSideRatio < 1 {
                    let ratio = min(longSideRatio, shortSideRatio)
                    targetSize = CGSize(width: round(naturalSize.width * ratio),
                                        height: round(naturalSize.height * ratio))
                } else {
                    targetSize = naturalSize
                }
                sizeAdjustedVideoSettings[AVVideoWidthKey] = targetSize.width
                sizeAdjustedVideoSettings[AVVideoHeightKey] = targetSize.height

                let xRatio = targetSize.width / naturalSize.width
                let yRatio = targetSize.height / naturalSize.height
                let ratio = min(xRatio, yRatio)
                let offset = CGPoint(x: (targetSize.width - naturalSize.width * ratio) / 2,
                                     y: (targetSize.height - naturalSize.height * ratio) / 2)
                var matrix = CGAffineTransform(translationX: offset.x / xRatio, y: offset.y / yRatio)
                matrix = matrix.scaledBy(x: ratio / xRatio, y: ratio / yRatio)
                transform = transform.concatenating(matrix)

                let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
                layerInstruction.setTransform(transform, at: .zero)
                let instruction = AVMutableVideoCompositionInstruction()
                instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
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
                videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: sizeAdjustedVideoSettings)
                videoInput.expectsMediaDataInRealTime = false
                if writer.canAdd(videoInput) {
                    writer.add(videoInput)
                }
            }
            let audioTracks = asset.tracks(withMediaType: .audio)
            if !audioTracks.isEmpty {
                // Audio output
                let audioOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: nil)
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
            writer.startSession(atSourceTime: timeRange.start)
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
        } catch {
            self.error = error
            status = .failed
            handler()
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
                    presentationTime = CMTimeSubtract(presentationTime, timeRange.start)
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
            complete()
        } else if reader.status == .failed {
            writer.cancelWriting()
            complete()
        } else {
            writer.finishWriting(completionHandler: complete)
        }
    }

    private func complete() {
        if writer.status == .failed || writer.status == .cancelled {
            try? FileManager.default.removeItem(at: outputURL)
            status = .failed
        } else {
            status = .completed
        }
        completionHandler?()
        completionHandler = nil
    }

}
