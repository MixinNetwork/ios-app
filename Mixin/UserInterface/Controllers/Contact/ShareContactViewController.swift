import UIKit

class ShareContactViewController: ForwardViewController {

    override func sendMessage(_ conversation: ForwardUser) {
        var newMessage = Message.createMessage(category: MessageCategory.SIGNAL_CONTACT.rawValue, conversationId: conversation.conversationId, userId: AccountAPI.shared.accountUserId)
        newMessage.sharedUserId = ownerUser!.userId
        let transferData = TransferContactData(userId: ownerUser!.userId)
        newMessage.content = try! JSONEncoder().encode(transferData).base64EncodedString()

        SendMessageService.shared.sendMessage(message: newMessage, ownerUser: conversation.toUser(), isGroupMessage: conversation.isGroup)
    }

    class func instance(ownerUser: UserItem) -> UIViewController {
        let vc = Storyboard.contact.instantiateViewController(withIdentifier: "share_contact") as! ShareContactViewController
        vc.ownerUser = ownerUser
        return ContainerViewController.instance(viewController: vc, title: Localized.PROFILE_SHARE_CARD)
    }


}
