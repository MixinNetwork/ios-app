import UIKit

class SendToViewController: ForwardViewController {

    private var photo: UIImage!

    override func forwardMessage(_ targetUser: ForwardUser) {
        var message = Message.createMessage(category: MessageCategory.SIGNAL_IMAGE.rawValue, conversationId: targetUser.conversationId, userId: AccountAPI.shared.accountUserId)
        let filename = "\(message.messageId).jpg"
        let path = MixinFile.url(ofChatDirectory: .photos, filename: filename)
        guard photo.saveToFile(path: path), FileManager.default.fileSize(path.path) > 0, photo.size.width > 0, photo.size.height > 0  else {
            NotificationCenter.default.postOnMain(name: .ErrorMessageDidAppear, object: Localized.CHAT_SEND_PHOTO_FAILED)
            return
        }
        message.thumbImage = photo.getBlurThumbnail().toBase64()
        message.mediaSize = FileManager.default.fileSize(path.path)
        message.mediaWidth = Int(photo.size.width)
        message.mediaHeight = Int(photo.size.height)
        message.mediaMimeType = "image/jpeg"
        message.mediaUrl = filename
        message.mediaStatus = MediaStatus.PENDING.rawValue

        DispatchQueue.global().async { [weak self] in
            SendMessageService.shared.sendMessage(message: message, ownerUser: targetUser.toUser(), isGroupMessage: targetUser.isGroup)
            DispatchQueue.main.async {
                self?.gotoConversationVC(targetUser)
            }
        }
    }

    class func instance(photo: UIImage) -> UIViewController {
        let vc = Storyboard.camera.instantiateViewController(withIdentifier: "sendto") as! SendToViewController
        vc.photo = photo
        return ContainerViewController.instance(viewController: vc, title: Localized.CAMERA_SEND_TO_TITLE)
    }
}
