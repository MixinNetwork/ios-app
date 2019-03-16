import UIKit
import AVKit

class SendMessagePeerSelectionViewController: PeerSelectionViewController {
    
    private var messageContent: MessageContent!
    
    class func instance(content: MessageContent) -> UIViewController {
        let vc = SendMessagePeerSelectionViewController()
        vc.messageContent = content
        return ContainerViewController.instance(viewController: vc, title: Localized.ACTION_SHARE_TO)
    }
    
    override func textBarRightButton() -> String? {
        return Localized.ACTION_SEND
    }

    override var tableRowHeight: CGFloat {
        return 70
    }
    
    override func work(selections: [Peer]) {
        container?.rightButton.isBusy = true
        let content = self.messageContent!
        DispatchQueue.global().async { [weak self] in
            for peer in selections {
                guard let message = SendMessagePeerSelectionViewController.makeMessage(content: content, to: peer) else {
                    continue
                }
                SendMessageService.shared.sendMessage(message: message, ownerUser: peer.user, isGroupMessage: peer.isGroup)
            }
            DispatchQueue.main.async {
                self?.popToConversationWithLastSelection()
            }
        }
    }
    
}

extension SendMessagePeerSelectionViewController {
    
    enum MessageContent {
        case message(MessageItem)
        case contact(String)
        case photo(UIImage)
        case text(String)
        case video(URL)
    }
    
    static func makeMessage(content: MessageContent, to peer: Peer) -> Message? {
        switch content {
        case .message(let message):
            return makeMessage(message: message, to: peer)
        case .contact(let userId):
            return makeMessage(userId: userId, to: peer)
        case .photo(let image):
            return makeMessage(image: image, to: peer)
        case .text(let text):
            return makeMessage(text: text, to: peer)
        case .video(let url):
            return makeMessage(videoUrl: url, to: peer)
        }
    }
    
    static func makeMessage(message: MessageItem, to peer: Peer) -> Message? {
        var newMessage = Message.createMessage(category: message.category,
                                               conversationId: peer.conversationId,
                                               userId: AccountAPI.shared.accountUserId)
        if message.category.hasSuffix("_TEXT") {
            newMessage.content = message.content
        } else if message.category.hasSuffix("_IMAGE") {
            newMessage.thumbImage = message.thumbImage
            newMessage.mediaSize = message.mediaSize
            newMessage.mediaWidth = message.mediaWidth
            newMessage.mediaHeight = message.mediaHeight
            newMessage.mediaMimeType = message.mediaMimeType
            newMessage.mediaUrl = message.mediaUrl
            newMessage.mediaStatus = MediaStatus.PENDING.rawValue
        } else if message.category.hasSuffix("_DATA") {
            newMessage.name = message.name
            newMessage.mediaSize = message.mediaSize
            newMessage.mediaMimeType = message.mediaMimeType
            newMessage.mediaUrl = message.mediaUrl
            newMessage.mediaStatus = MediaStatus.PENDING.rawValue
        } else if message.category.hasSuffix("_AUDIO") {
            newMessage.mediaSize = message.mediaSize
            newMessage.mediaMimeType = message.mediaMimeType
            newMessage.mediaUrl = message.mediaUrl
            newMessage.mediaWaveform = message.mediaWaveform
            newMessage.mediaDuration = message.mediaDuration
            newMessage.mediaStatus = MediaStatus.PENDING.rawValue
        } else if message.category.hasSuffix("_VIDEO") {
            newMessage.thumbImage = message.thumbImage
            newMessage.mediaSize = message.mediaSize
            newMessage.mediaWidth = message.mediaWidth
            newMessage.mediaHeight = message.mediaHeight
            newMessage.mediaMimeType = message.mediaMimeType
            newMessage.mediaUrl = message.mediaUrl
            newMessage.mediaStatus = MediaStatus.PENDING.rawValue
            newMessage.mediaDuration = message.mediaDuration
        } else if message.category.hasSuffix("_STICKER") {
            newMessage.mediaUrl = message.mediaUrl
            newMessage.stickerId = message.stickerId
            newMessage.mediaStatus = MediaStatus.PENDING.rawValue
            let transferData = TransferStickerData(stickerId: message.stickerId, name: nil, albumId: nil)
            newMessage.content = try! JSONEncoder().encode(transferData).base64EncodedString()
        } else if message.category.hasSuffix("_CONTACT") {
            guard let sharedUserId = message.sharedUserId else {
                return nil
            }
            newMessage.sharedUserId = sharedUserId
            let transferData = TransferContactData(userId: sharedUserId)
            newMessage.content = try! JSONEncoder().encode(transferData).base64EncodedString()
        }
        return newMessage
    }
    
    static func makeMessage(userId: String, to peer: Peer) -> Message? {
        var message = Message.createMessage(category: MessageCategory.SIGNAL_CONTACT.rawValue,
                                            conversationId: peer.conversationId,
                                            userId: AccountAPI.shared.accountUserId)
        message.sharedUserId = userId
        let transferData = TransferContactData(userId: userId)
        message.content = try! JSONEncoder().encode(transferData).base64EncodedString()
        return message
    }
    
    static func makeMessage(image: UIImage, to peer: Peer) -> Message? {
        var message = Message.createMessage(category: MessageCategory.SIGNAL_IMAGE.rawValue,
                                            conversationId: peer.conversationId,
                                            userId: AccountAPI.shared.accountUserId)
        let filename = message.messageId + ExtensionName.jpeg.withDot
        let path = MixinFile.url(ofChatDirectory: .photos, filename: filename)
        guard image.saveToFile(path: path), FileManager.default.fileSize(path.path) > 0, image.size.width > 0, image.size.height > 0 else {
            UIApplication.showHud(style: .error, text: Localized.TOAST_OPERATION_FAILED)
            return nil
        }
        message.thumbImage = image.base64Thumbnail()
        message.mediaSize = FileManager.default.fileSize(path.path)
        message.mediaWidth = Int(image.size.width)
        message.mediaHeight = Int(image.size.height)
        message.mediaMimeType = "image/jpeg"
        message.mediaUrl = filename
        message.mediaStatus = MediaStatus.PENDING.rawValue
        return message
    }
    
    static func makeMessage(text: String, to peer: Peer) -> Message {
        var message = Message.createMessage(category: MessageCategory.SIGNAL_TEXT.rawValue,
                                            conversationId: peer.conversationId,
                                            userId: AccountAPI.shared.accountUserId)
        message.content = text
        return message
    }
    
    static func makeMessage(videoUrl: URL, to peer: Peer) -> Message? {
        let asset = AVAsset(url: videoUrl)
        guard asset.duration.isValid, let videoTrack = asset.tracks(withMediaType: .video).first else {
            return nil
        }
        var message = Message.createMessage(category: MessageCategory.SIGNAL_VIDEO.rawValue,
                                            conversationId: peer.conversationId,
                                            userId: AccountAPI.shared.accountUserId)
        let filename = videoUrl.lastPathComponent.substring(endChar: ".")
        let thumbnailFilename = filename + ExtensionName.jpeg.withDot
        if let thumbnail = UIImage(withFirstFrameOfVideoAtURL: videoUrl) {
            let thumbnailURL = MixinFile.url(ofChatDirectory: .videos, filename: thumbnailFilename)
            thumbnail.saveToFile(path: thumbnailURL)
            message.thumbImage = thumbnail.base64Thumbnail()
        } else {
            return nil
        }
        message.mediaDuration = Int64(asset.duration.seconds * millisecondsPerSecond)
        let size = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
        message.mediaWidth = Int(abs(size.width))
        message.mediaHeight = Int(abs(size.height))
        message.mediaSize = FileManager.default.fileSize(videoUrl.path)
        message.mediaMimeType = FileManager.default.mimeType(ext: videoUrl.pathExtension)
        message.mediaUrl = videoUrl.lastPathComponent
        message.mediaStatus = MediaStatus.PENDING.rawValue
        return message
    }
    
}
