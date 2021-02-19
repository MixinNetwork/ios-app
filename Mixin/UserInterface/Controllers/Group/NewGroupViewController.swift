import UIKit
import MixinServices

class NewGroupViewController: KeyboardBasedLayoutViewController {
    
    @IBOutlet weak var groupImageView: CornerImageView!
    @IBOutlet weak var participentLabel: UILabel!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var createButton: RoundedButton!
    
    @IBOutlet weak var keyboardPlaceholderHeightConstraint: NSLayoutConstraint!
    
    private let conversationId = UUID().uuidString.lowercased()
    private var members = [GroupUser]()
    private var shouldLayoutByKeyboard = true
    
    private var groupName: String {
        return nameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        nameTextField.addTarget(self, action: #selector(nameChangedAction(_:)), for: .editingChanged)
        participentLabel.text = Localized.GROUP_TITLE_MEMBERS(count: "\(members.count + 1)")
        loadGroupIcon()
        nameTextField.becomeFirstResponder()
    }
    
    override func layout(for keyboardFrame: CGRect) {
        guard shouldLayoutByKeyboard else {
            return
        }
        keyboardPlaceholderHeightConstraint.constant = view.frame.height - keyboardFrame.origin.y
        view.layoutIfNeeded()
    }
    
    @objc func nameChangedAction(_ sender: Any) {
        createButton.isEnabled = !groupName.isEmpty
    }
    
    @IBAction func createAction(_ sender: Any) {
        guard !createButton.isBusy else {
            return
        }
        
        createButton.isBusy = true
        
        let participants = members.map {
            ParticipantRequest(userId: $0.userId, role: "")
        }
        let request = ConversationRequest(conversationId: self.conversationId, name: self.groupName, category: ConversationCategory.GROUP.rawValue, participants: participants, duration: nil, announcement: nil)
        ConversationAPI.createConversation(conversation: request) { [weak self](result) in
            guard let weakSelf = self else {
                return
            }
            switch result {
            case let .success(response):
                weakSelf.saveConversation(response: response)
            case let .failure(error):
                if !ReachabilityManger.shared.isReachable {
                    weakSelf.saveOfflineConversation()
                } else {
                    showAutoHiddenHud(style: .error, text: error.localizedDescription)
                    weakSelf.createButton.isBusy = false
                }
            }
        }
    }
    
    private func loadGroupIcon() {
        guard let account = LoginManager.shared.account else {
            return
        }
        var participants: [ParticipantUser] = members.map { (user) in
            ParticipantUser(conversationId: conversationId, user: user)
        }
        participants.insert(ParticipantUser(conversationId: conversationId, account: account), at: 0)
        DispatchQueue.global().async { [weak self] in
            let groupImage = GroupIconMaker.make(participants: participants) ?? nil
            DispatchQueue.main.async {
                self?.groupImageView.image = groupImage
            }
        }
    }
    
    private func saveGroupImage(conversationId: String, participants: [ParticipantUser]) -> String? {
        guard let image = groupImageView.image else {
            return nil
        }
        do {
            let filename = try GroupIconSaver.save(image: image,
                                                   forGroupWith: conversationId,
                                                   participants: participants)
            ConversationDAO.shared.updateIconUrl(conversationId: conversationId,
                                                 iconUrl: filename)
            return filename
        } catch let GroupIconSaver.Error.fileExists(filename) {
            return filename
        } catch {
            reporter.report(error: error)
            return nil
        }
    }
    
    private func saveOfflineConversation() {
        let converstionId = self.conversationId
        let name = self.groupName
        let members = self.members
        
        DispatchQueue.global().async { [weak self] in
            ConversationDAO.shared.createConversation(conversationId: converstionId, name: name, members: members) { success in
                guard success else {
                    return
                }
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: MixinServices.conversationDidChangeNotification, object: nil)
                    self?.shouldLayoutByKeyboard = false
                    self?.navigationController?.backToHome()
                }
            }
        }
    }
    
    private func saveConversation(response: ConversationResponse) {
        DispatchQueue.global().async { [weak self] in
            let (conversation, participantUsers) = ConversationDAO.shared.createNewConversation(response: response)
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                if let iconUrl = weakSelf.saveGroupImage(conversationId: conversation.conversationId, participants: participantUsers) {
                    conversation.iconUrl = iconUrl
                }
                weakSelf.shouldLayoutByKeyboard = false
                weakSelf.nameTextField.resignFirstResponder()
                let vc = ConversationViewController.instance(conversation: conversation)
                weakSelf.navigationController?.pushViewController(withBackRoot: vc)
            }
        }
    }
    
    class func instance(members: [GroupUser]) -> UIViewController {
        let vc = R.storyboard.group.new_group()!
        vc.members = members
        return ContainerViewController.instance(viewController: vc, title: Localized.GROUP_NAVIGATION_TITLE_NEW_GROUP)
    }
    
}
