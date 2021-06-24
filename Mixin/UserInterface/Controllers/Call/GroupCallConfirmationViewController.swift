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
        updateTitle(isPeerToPeerCall: false, status: Call.Status.incoming.localizedDescription)
        membersCollectionView.isHidden = false
        hangUpStackView.alpha = 0
        acceptStackView.alpha = 1
        acceptButtonTrailingConstraint.priority = .defaultLow
        acceptButtonCenterXConstraint.priority = .defaultHigh
    }
    
    override func minimizeAction(_ sender: Any) {
        CallService.shared.dismissCallingInterface()
    }
    
    override func acceptAction(_ sender: Any) {
        CallService.shared.requestStartGroupCall(conversation: conversation, invitingMembers: [])
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
