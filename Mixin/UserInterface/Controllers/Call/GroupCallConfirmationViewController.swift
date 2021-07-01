import UIKit
import MixinServices

class GroupCallConfirmationViewController: CallViewController {
    
    private let conversation: ConversationItem
    
    init(conversation: ConversationItem, service: CallService) {
        self.conversation = conversation
        super.init(service: service)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setFunctionSwitchesHidden(true)
        setConnectionButtonsEnabled(true)
        minimizeButton.setImage(R.image.ic_title_close(), for: .normal)
        minimizeButton.tintColor = .white
        titleLabel.text = R.string.localizable.chat_menu_group_call()
        membersCollectionView.isHidden = false
        hangUpStackView.alpha = 0
        acceptStackView.alpha = 1
        acceptButtonTrailingConstraint.priority = .defaultLow
        acceptButtonCenterXConstraint.priority = .defaultHigh
    }
    
    override func minimizeAction(_ sender: Any) {
        hideContentView {
            CallService.shared.removeViewControllerAsContainersChildIfNeeded(self)
        }
    }
    
    override func acceptAction(_ sender: Any) {
        CallService.shared.requestStartGroupCall(conversation: conversation, invitingMembers: [], animated: false)
    }
    
    override func learnMoreAboutEncryption() {
        guard let container = UIApplication.currentActivity() else {
            return
        }
        hideContentView {
            CallService.shared.removeViewControllerAsContainersChildIfNeeded(self)
            MixinWebViewController.presentInstance(with: .init(conversationId: "", initialUrl: .aboutEncryption), asChildOf: container)
        }
    }
    
    func loadMembers(with userIds: [String]) {
        DispatchQueue.global().async {
            let members = UserDAO.shared.getUsers(with: userIds)
            DispatchQueue.main.async {
                self.members = members
                if self.isViewLoaded {
                    self.membersCollectionView.reloadData()
                }
            }
        }
    }
    
}
