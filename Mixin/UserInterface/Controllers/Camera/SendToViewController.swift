import UIKit
import AVKit

class SendToViewController: ForwardViewController {

    private var photo: UIImage!
    private var text: String!
    private var videoUrl: URL!

    override func forwardMessage(_ targetUser: ForwardUser) {
        var msg: Message?
        if text != nil {
            msg = createTextMessage(targetUser)
        } else if photo != nil {
            msg = createPhotoMessage(targetUser)
        } else if videoUrl != nil {
            msg = createVideoMessage(targetUser)
        }

        guard let message = msg else {
            return
        }
        DispatchQueue.global().async { [weak self] in
            SendMessageService.shared.sendMessage(message: message, ownerUser: targetUser.toUser(), isGroupMessage: targetUser.isGroup)
            DispatchQueue.main.async {
                self?.gotoConversationVC(targetUser)
            }
        }
    }

    class func instance(photo: UIImage? = nil, text: String? = nil, videoUrl: URL? = nil) -> UIViewController {
        let vc = Storyboard.camera.instantiateViewController(withIdentifier: "sendto") as! SendToViewController
        vc.photo = photo
        vc.text = text
        vc.videoUrl = videoUrl
        return ContainerViewController.instance(viewController: vc, title: Localized.CAMERA_SEND_TO_TITLE)
    }
}

extension SendToViewController {

    private func createPhotoMessage(_ targetUser: ForwardUser) -> Message? {
        guard photo != nil else {
            return nil
        }
        var message = Message.createMessage(category: MessageCategory.SIGNAL_IMAGE.rawValue, conversationId: targetUser.conversationId, userId: AccountAPI.shared.accountUserId)
        let filename = message.messageId + ExtensionName.jpeg.withDot
        let path = MixinFile.url(ofChatDirectory: .photos, filename: filename)
        guard photo.saveToFile(path: path), FileManager.default.fileSize(path.path) > 0, photo.size.width > 0, photo.size.height > 0  else {
            NotificationCenter.default.postOnMain(name: .ErrorMessageDidAppear, object: Localized.CHAT_SEND_PHOTO_FAILED)
            return nil
        }
        message.thumbImage = photo.getBlurThumbnail().toBase64()
        message.mediaSize = FileManager.default.fileSize(path.path)
        message.mediaWidth = Int(photo.size.width)
        message.mediaHeight = Int(photo.size.height)
        message.mediaMimeType = "image/jpeg"
        message.mediaUrl = filename
        message.mediaStatus = MediaStatus.PENDING.rawValue
        return message
    }

    private func createTextMessage(_ targetUser: ForwardUser) -> Message? {
        guard text != nil else {
            return nil
        }
        var message = Message.createMessage(category: MessageCategory.SIGNAL_TEXT.rawValue, conversationId: targetUser.conversationId, userId: AccountAPI.shared.accountUserId)
        message.content = text
        return message
    }

    private func createVideoMessage(_ targetUser: ForwardUser) -> Message? {
        guard let url = self.videoUrl else {
            return nil
        }
        let asset = AVAsset(url: videoUrl)
        guard asset.duration.isValid, let videoTrack = asset.tracks(withMediaType: .video).first else {
            return nil
        }
        var message = Message.createMessage(category: MessageCategory.SIGNAL_VIDEO.rawValue, conversationId: targetUser.conversationId, userId: AccountAPI.shared.accountUserId)
        let filename = url.lastPathComponent.substring(endChar: ".")
        let thumbnailFilename = filename + ExtensionName.jpeg.withDot
        if let thumbnail = UIImage(withFirstFrameOfVideoAtURL: url) {
            let thumbnailURL = MixinFile.url(ofChatDirectory: .videos, filename: thumbnailFilename)
            thumbnail.saveToFile(path: thumbnailURL)
            message.thumbImage = thumbnail.getBlurThumbnail().toBase64()
        } else {
            return nil
        }
        message.mediaDuration = Int64(asset.duration.seconds * millisecondsPerSecond)
        let size = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
        message.mediaWidth = Int(abs(size.width))
        message.mediaHeight = Int(abs(size.height))
        message.mediaSize = FileManager.default.fileSize(url.path)
        message.mediaMimeType = FileManager.default.mimeType(ext: url.pathExtension)
        message.mediaUrl = url.lastPathComponent
        message.mediaStatus = MediaStatus.PENDING.rawValue
        return message
    }

}
