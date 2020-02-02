import UIKit
import MixinServices

class GroupAnnouncementViewController: AnnouncementViewController {

    private var conversation: ConversationItem!

    override var announcement: String {
        return conversation.announcement
    }
    
    override func saveAction(_ sender: Any) {
        guard !saveButton.isBusy else {
            return
        }
        saveButton.isBusy = true
        ConversationAPI.shared.updateGroupAnnouncement(conversationId: conversation.conversationId, announcement: newAnnouncement) { [weak self] (response) in
            switch response {
            case let .success(conversation):
                let change = ConversationChange(conversationId: conversation.conversationId, action: .updateConversation(conversation: conversation))
                NotificationCenter.default.post(name: .ConversationDidChange, object: change)
                self?.saveSuccessAction()
            case let .failure(error):
                self?.saveFailedAction(error: error)
            }
        }
    }
    
    class func instance(conversation: ConversationItem) -> UIViewController {
        let vc = GroupAnnouncementViewController()
        vc.conversation = conversation
        let container = ContainerViewController.instance(viewController: vc, title: Localized.GROUP_NAVIGATION_TITLE_ANNOUNCEMENT)
        return container
    }
    
}
