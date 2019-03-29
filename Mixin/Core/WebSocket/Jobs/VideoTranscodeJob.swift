import Foundation
import AVFoundation

class VideoTranscodeJob: AsynchronousJob {
    
    var message: Message
    var inputAsset: AVAsset?
    
    private lazy var filename = UUID().uuidString.lowercased()
    private lazy var videoFilename = filename + ExtensionName.mp4.withDot
    private lazy var thumbnailFilename = filename + ExtensionName.jpeg.withDot
    private lazy var videoSettings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecH264,
        AVVideoWidthKey: 1280,
        AVVideoHeightKey: 720,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 1500000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel
        ]
    ]
    private lazy var audioSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVNumberOfChannelsKey: 2,
        AVSampleRateKey: 44100,
        AVEncoderBitRateKey: 128000
    ]
    
    init(message: Message) {
        self.message = message
        super.init()
    }
    
    override func getJobId() -> String {
        return "video-transcode-" + filename
    }
    
    override func execute() -> Bool {
        guard !isCancelled && AccountAPI.shared.didLogin else {
            return false
        }
        guard let asset = inputAsset else {
            return false
        }
        let videoUrl = MixinFile.url(ofChatDirectory: .videos, filename: videoFilename)
        let exportSession = AssetExportSession(asset: asset, videoSettings: videoSettings, audioSettings: audioSettings, outputURL: videoUrl)
        exportSession.exportAsynchronously {
            if self.isCancelled {
                try? FileManager.default.removeItem(at: videoUrl)
            } else if exportSession.status == .completed {
                let thumbnail = UIImage(withFirstFrameOfVideoAtAsset: asset)
                let thumbnailUrl = MixinFile.url(ofChatDirectory: .videos, filename: self.thumbnailFilename)
                thumbnail?.saveToFile(path: thumbnailUrl)
                let size = FileManager.default.fileSize(videoUrl.path)
                self.message.mediaUrl = self.videoFilename
                self.message.mediaSize = size
                MixinDatabase.shared.insertOrReplace(objects: [self.message])
                let change = ConversationChange(conversationId: self.message.conversationId, action: .updateMessage(messageId: self.message.messageId))
                NotificationCenter.default.afterPostOnMain(name: .ConversationDidChange, object: change)
            }
            self.finishJob()
        }
        return true
    }
    
}
