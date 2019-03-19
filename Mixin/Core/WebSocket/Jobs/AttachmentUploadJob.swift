import Foundation
import UIKit
import Photos
import Bugsnag

class AttachmentUploadJob: UploadOrDownloadJob {

    private static let videoSettings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecH264,
        AVVideoWidthKey: 1280,
        AVVideoHeightKey: 720,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 1500000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel
        ]
    ]
    private static let audioSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVNumberOfChannelsKey: 2,
        AVSampleRateKey: 44100,
        AVEncoderBitRateKey: 128000
    ]

    internal var attachResponse: AttachmentResponse?
    internal var fileUrl: URL? {
        guard let mediaUrl = message.mediaUrl, !mediaUrl.isEmpty else {
            return nil
        }
        return MixinFile.url(ofChatDirectory: .photos, filename: mediaUrl)
    }

    private var stream: InputStream?
    
    init(message: Message) {
        super.init(messageId: message.messageId)
        super.message = message
    }

    class func jobId(messageId: String) -> String {
        return "attachment-upload-\(messageId)"
    }
    
    override func getJobId() -> String {
        return AttachmentUploadJob.jobId(messageId: message.messageId)
    }

    override func execute() -> Bool {
        guard !self.message.messageId.isEmpty else {
            return false
        }
        guard !processAttachment() else {
            return true
        }

        return  uploadAction()
    }

    @discardableResult
    private func uploadAction() -> Bool {
        repeat {
            switch MessageAPI.shared.requestAttachment() {
            case let .success(attachResponse):
                self.attachResponse = attachResponse
                guard uploadAttachment(attachResponse: attachResponse) else {
                    return false
                }
                return true
            case let .failure(error):
                guard error.isClientError || error.isServerError else {
                    return false
                }
                checkNetworkAndWebSocket()
                Thread.sleep(forTimeInterval: 2)
            }
        } while AccountAPI.shared.didLogin && !isCancelled
        return false
    }

    private func processAttachment() -> Bool {
        guard let identifier = message.mediaIdentifier, !identifier.isEmpty else {
            return false
        }
        guard !message.hasProcessedAsset() else {
            return false
        }
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject else {
            processAssetFailed()
            return true
        }

        let messageId = message.messageId
        if message.category.hasSuffix("_VIDEO") {
            let requestOptions = PHVideoRequestOptions()
            requestOptions.version = .current
            requestOptions.deliveryMode = .highQualityFormat
            requestOptions.isNetworkAccessAllowed = true
            PHImageManager.default().requestAVAsset(forVideo: asset, options: requestOptions) { [weak self](avasset, _, _) in
                guard let avasset = avasset else {
                    self?.processAssetFailed()
                    return
                }
                let thumbImage = UIImage(withFirstFrameOfVideoAtAsset: avasset)?.base64Thumbnail()
                let mediaUrl = messageId + ExtensionName.mp4.withDot
                let outputURL = MixinFile.url(ofChatDirectory: .videos, filename: mediaUrl)
                let exportSession = AssetExportSession(asset: avasset, videoSettings: AttachmentUploadJob.videoSettings, audioSettings: AttachmentUploadJob.audioSettings, outputURL: outputURL)
                exportSession.exportAsynchronously {
                    if exportSession.status == .completed {
                        self?.updateMessage(thumbImage: thumbImage, mediaUrl: mediaUrl, mediaSize: FileManager.default.fileSize(outputURL.path))
                        self?.uploadAction()
                    } else {
                        self?.processAssetFailed()
                    }
                }
            }
        } else {
            if let fileExtension = animateFileExtension(asset: asset) {
                PHImageManager.default().requestImageData(for: asset, options: nil, resultHandler: { [weak self](data, _, _, _) in
                    guard let data = data else {
                        self?.processAssetFailed()
                        return
                    }
                    let thumbImage = UIImage(data: data)?.base64Thumbnail()
                    let mediaUrl = messageId + fileExtension
                    let outputURL = MixinFile.url(ofChatDirectory: .photos, filename: mediaUrl)
                    do {
                        try data.write(to: outputURL)
                    } catch {
                        self?.processAssetFailed()
                        return
                    }
                    guard FileManager.default.fileSize(outputURL.path) > 0 else {
                        self?.processAssetFailed()
                        return
                    }
                    self?.updateMessage(thumbImage: thumbImage, mediaUrl: mediaUrl, mediaSize: FileManager.default.fileSize(outputURL.path))
                    self?.uploadAction()
                })
            } else {
                let requestOptions = PHImageRequestOptions()
                requestOptions.version = .current
                requestOptions.isSynchronous = true
                requestOptions.deliveryMode = .highQualityFormat
                requestOptions.isNetworkAccessAllowed = true
                PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: requestOptions, resultHandler: { [weak self](image, _) in
                    guard let image = image else {
                        self?.finishJob()
                        return
                    }
                    let thumbImage = image.base64Thumbnail()
                    let mediaUrl = messageId + ExtensionName.jpeg.withDot
                    let outputURL = MixinFile.url(ofChatDirectory: .photos, filename: mediaUrl)
                    let targetPhoto = image.scaleForUpload()
                    guard targetPhoto.saveToFile(path: outputURL), FileManager.default.fileSize(outputURL.path) > 0 else {
                        self?.processAssetFailed()
                        return
                    }
                    
                    self?.updateMessage(thumbImage: thumbImage, mediaUrl: mediaUrl, mediaSize: FileManager.default.fileSize(outputURL.path))
                    self?.uploadAction()
                })
            }
        }
        return true
    }

    private func updateMessage(thumbImage: String?, mediaUrl: String, mediaSize: Int64) {
        message.thumbImage = thumbImage
        message.mediaUrl = mediaUrl
        message.mediaSize = mediaSize
        MessageDAO.shared.updateMessageUpload(mediaUrl: mediaUrl, thumbImage: thumbImage, mediaSize: mediaSize, messageId: message.messageId)
    }

    private func processAssetFailed() {
        finishJob()
        showHud(style: .error, text: Localized.CHAT_SEND_VIDEO_FAILED)
    }

    private func animateFileExtension(asset: PHAsset) -> String? {
        guard let filename = PHAssetResource.assetResources(for: asset).first?.originalFilename.lowercased(), let startIndex = filename.index(of: "."), startIndex < filename.endIndex else {
            return nil
        }
        let fileExtension = String(filename[startIndex..<filename.endIndex])
        guard fileExtension.hasSuffix(".webp") || fileExtension.hasSuffix(".gif") else {
            return nil
        }
        return fileExtension
    }

    private func uploadAttachment(attachResponse: AttachmentResponse) -> Bool {
        guard let uploadUrl = attachResponse.uploadUrl, !uploadUrl.isEmpty, var request = try? URLRequest(url: uploadUrl, method: .put) else {
            UIApplication.trackError("AttachmentUploadJob", action: "uploadAttachment upload_url is nil", userInfo: ["uploadUrl": "\(attachResponse.uploadUrl ?? "")"])
            return false
        }
        guard let fileUrl = fileUrl else {
            return false
        }

        let contentLength: Int
        if message.category.hasPrefix("SIGNAL_") {
            if let inputStream = AttachmentEncryptingInputStream(url: fileUrl) {
                contentLength = inputStream.contentLength
                stream = inputStream
            } else {
                UIApplication.trackError("AttachmentUploadJob", action: "AttachmentEncryptingInputStream init failed")
                return false
            }
        } else {
            stream = InputStream(url: fileUrl)
            if stream == nil {
                UIApplication.trackError("AttachmentUploadJob", action: "InputStream init failed")
                return false
            } else {
                contentLength = Int(FileManager.default.fileSize(fileUrl.path))
            }
        }
        guard let inputStream = stream, contentLength > 0 else {
            return false
        }
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue("\(contentLength)", forHTTPHeaderField: "Content-Length")
        request.setValue("public-read", forHTTPHeaderField: "x-amz-acl")
        request.setValue("Connection", forHTTPHeaderField: "close")
        request.cachePolicy = .reloadIgnoringCacheData
        request.httpBodyStream = inputStream
        
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        task = session.dataTask(with: request, completionHandler: completionHandler)
        task?.resume()
        session.finishTasksAndInvalidate()
        return true
    }

    override func taskFinished() {
        guard let attachResponse = self.attachResponse else {
            return
        }
        let key = (stream as? AttachmentEncryptingInputStream)?.key
        let digest = (stream as? AttachmentEncryptingInputStream)?.digest
        let content = getMediaDataText(attachmentId: attachResponse.attachmentId, key: key, digest: digest)
        message.content = content
        MessageDAO.shared.updateMessageContentAndMediaStatus(content: content, mediaStatus: .DONE, messageId: message.messageId, conversationId: message.conversationId)

        SendMessageService.shared.sendMessage(message: message)
        SendMessageService.shared.sendSessionMessage(message: message, data: content)
    }

    internal func getMediaDataText(attachmentId: String, key: Data?, digest: Data?) -> String {
        let transferMediaData = TransferAttachmentData(key: key, digest: digest, attachmentId: attachmentId, mimeType: message.mediaMimeType!, width: message.mediaWidth, height: message.mediaHeight, size:message.mediaSize!, thumbnail: message.thumbImage, name: message.name, duration: message.mediaDuration, waveform: message.mediaWaveform)
        return (try? jsonEncoder.encode(transferMediaData).base64EncodedString()) ?? ""
    }
}

extension AttachmentUploadJob: URLSessionTaskDelegate {

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        let change = ConversationChange(conversationId: message.conversationId,
                                        action: .updateUploadProgress(messageId: message.messageId, progress: progress))
        NotificationCenter.default.postOnMain(name: .ConversationDidChange, object: change)
    }

}

private extension Message {

    func hasProcessedAsset() -> Bool {
        guard let mediaUrl = self.mediaUrl, !mediaUrl.isEmpty else {
            return false
        }

        let directory: MixinFile.ChatDirectory!
        if category.hasSuffix("_VIDEO") {
            directory = .videos
        } else if category.hasSuffix("_IMAGE") {
            directory = .photos
        } else {
            return true
        }

        let mediaPath = MixinFile.url(ofChatDirectory: directory, filename: mediaUrl).path
        return FileManager.default.fileExists(atPath: mediaPath) && FileManager.default.fileSize(mediaPath) > 0
    }

}
