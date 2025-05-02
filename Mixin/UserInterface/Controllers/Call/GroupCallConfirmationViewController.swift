import UIKit
import MixinServices

class GroupCallConfirmationViewController: CallViewController {
    
    private let conversation: ConversationItem
    
    override var membersCountText: String? {
        R.string.localizable.title_participants_count(members.count)
    }
    
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
        titleLabel.text = conversation.name
        statusLabel.text = nil
        membersCollectionView.isHidden = false
        membersCountLabel.text = R.string.localizable.title_participants_count(members.count)
        hangUpStackView.alpha = 0
        acceptStackView.alpha = 1
        acceptButtonTrailingConstraint.priority = .defaultLow
        acceptButtonCenterXConstraint.priority = .defaultHigh
    }
    
    override func minimizeAction(_ sender: Any) {
        hideContentView {
            self.service.removeViewControllerAsContainersChildIfNeeded(self)
        }
    }
    
    override func acceptAction(_ sender: Any) {
        service.makeGroupCall(conversation: conversation, invitees: [])
    }
    
    override func learnMoreAboutEncryption() {
        guard let container = UIApplication.homeContainerViewController else {
            return
        }
        hideContentView {
            self.service.removeViewControllerAsContainersChildIfNeeded(self)
            container.presentWebViewController(context: .init(conversationId: "", initialUrl: .aboutEncryption))
        }
    }
    
    func loadMembers(with userIds: [String]) {
        DispatchQueue.global().async {
            let members = UserDAO.shared.getUsers(with: userIds)
            DispatchQueue.main.async {
                self.members = members
                if self.isViewLoaded {
                    self.membersCollectionView.reloadData()
                    self.membersCountLabel.text = R.string.localizable.title_participants_count(members.count)
                    self.view.setNeedsLayout()
                    self.view.layoutIfNeeded()
                    self.updateMembersCountLabel()
                }
            }
        }
    }
    
}
