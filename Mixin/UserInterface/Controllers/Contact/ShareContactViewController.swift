import UIKit

class ShareContactViewController: ForwardViewController {

    override func forwardMessage(_ targetUser: ForwardUser) {
        var newMessage = Message.createMessage(category: MessageCategory.SIGNAL_CONTACT.rawValue, conversationId: targetUser.conversationId, userId: AccountAPI.shared.accountUserId)
        newMessage.sharedUserId = ownerUser!.userId
        let transferData = TransferContactData(userId: ownerUser!.userId)
        newMessage.content = try! JSONEncoder().encode(transferData).base64EncodedString()

        DispatchQueue.global().async { [weak self] in
            SendMessageService.shared.sendMessage(message: newMessage, ownerUser: targetUser.toUser(), isGroupMessage: targetUser.isGroup)
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                weakSelf.gotoConversationVC(targetUser)
            }
        }
    }

    class func instance(ownerUser: UserItem) -> UIViewController {
        let vc = Storyboard.contact.instantiateViewController(withIdentifier: "share_contact") as! ShareContactViewController
        vc.ownerUser = ownerUser
        return ContainerViewController.instance(viewController: vc, title: Localized.PROFILE_SHARE_CARD)
    }


}
