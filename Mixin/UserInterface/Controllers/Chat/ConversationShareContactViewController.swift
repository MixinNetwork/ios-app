import UIKit

class ConversationShareContactViewController: SendMessagePeerSelectionViewController, MixinNavigationAnimating {
    
    private var ownerUser: UserItem?
    private var parentConversation: ConversationItem!
    
    override var content: PeerSelectionViewController.Content {
        return .contacts
    }
    
    override func work(selections: [Peer]) {
        let ownerUser = self.ownerUser
        let parentConversation = self.parentConversation!
        DispatchQueue.global().async { [weak self] in
            for peer in selections {
                guard let userId = peer.user?.userId else {
                    continue
                }
                var message = Message.createMessage(category: MessageCategory.SIGNAL_CONTACT.rawValue,
                                                    conversationId: parentConversation.conversationId,
                                                    userId: AccountAPI.shared.accountUserId)
                message.sharedUserId = userId
                let transferData = TransferContactData(userId: userId)
                message.content = try! JSONEncoder().encode(transferData).base64EncodedString()
                SendMessageService.shared.sendMessage(message: message,
                                                      ownerUser: ownerUser,
                                                      isGroupMessage: parentConversation.isGroup())
            }
            DispatchQueue.main.async {
                self?.navigationController?.popViewController(animated: true)
            }
        }
       
    }
    
    class func instance(ownerUser: UserItem?, conversation: ConversationItem) -> UIViewController {
        let vc = ConversationShareContactViewController()
        vc.ownerUser = ownerUser
        vc.parentConversation = conversation
        return ContainerViewController.instance(viewController: vc, title: Localized.PROFILE_SHARE_CARD)
    }
    
}
