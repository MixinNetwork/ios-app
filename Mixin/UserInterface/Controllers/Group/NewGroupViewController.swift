import UIKit
import Bugsnag

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
        let windowHeight = AppDelegate.current.window!.bounds.height
        keyboardPlaceholderHeightConstraint.constant = windowHeight - keyboardFrame.origin.y
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
        ConversationAPI.shared.createConversation(conversation: request) { [weak self](result) in
            guard let weakSelf = self else {
                return
            }
            switch result {
            case let .success(response):
                weakSelf.saveGroupImage()
                weakSelf.saveConversation(conversation: response)
            case let .failure(error):
                if !NetworkManager.shared.isReachable {
                    weakSelf.saveOfflineConversation()
                } else {
                    showHud(style: .error, text: error.localizedDescription)
                    weakSelf.createButton.isBusy = false
                }
            }
        }
    }
    
    private func loadGroupIcon() {
        guard let account = AccountAPI.shared.account else {
            return
        }
        var participants: [ParticipantUser] = members.map { (user) in
            return ParticipantUser.createParticipantUser(conversationId: conversationId, user: user)
        }
        participants.insert(ParticipantUser.createParticipantUser(conversationId: conversationId, account: account), at: 0)
        DispatchQueue.global().async { [weak self] in
            guard let groupImage = UIImage.makeGroupImage(participants: participants) else {
                return
            }
            
            DispatchQueue.main.async {
                self?.groupImageView.image = groupImage
            }
        }
    }
    
    private func saveGroupImage() {
        guard let groupImage = groupImageView.image else {
            return
        }
        
        var participantIds: [String] = members.map { (member) in
            if member.avatarUrl.isEmpty {
                return String(member.fullName.prefix(1))
            } else {
                return member.avatarUrl
            }
        }
        participantIds.insert(AccountAPI.shared.accountUserId, at: 0)
        let imageFile = conversationId + "-" + participantIds.joined().md5() + ".png"
        let imageUrl = MixinFile.groupIconsUrl.appendingPathComponent(imageFile)
        
        guard !FileManager.default.fileExists(atPath: imageUrl.path) else {
            return
        }
        
        do {
            if let data = groupImage.pngData() {
                try data.write(to: imageUrl)
            }
        } catch {
            Bugsnag.notifyError(error)
        }
    }
    
    private func saveOfflineConversation() {
        let converstionId = self.conversationId
        let name = self.groupName
        let members = self.members
        
        DispatchQueue.global().async { [weak self] in
            if ConversationDAO.shared.createConversation(conversationId: converstionId, name: name, members: members) {
                DispatchQueue.main.async {
                    NotificationCenter.default.afterPostOnMain(name: .ConversationDidChange)
                    self?.shouldLayoutByKeyboard = false
                    self?.navigationController?.backToHome()
                }
            }
        }
    }
    
    private func saveConversation(conversation: ConversationResponse) {
        DispatchQueue.global().async { [weak self] in
            guard ConversationDAO.shared.createConversation(conversation: conversation, targetStatus: .SUCCESS) else {
                DispatchQueue.main.async {
                    self?.createButton.isBusy = false
                }
                return
            }
            guard let conversation = ConversationDAO.shared.getConversation(conversationId: conversation.conversationId) else {
                return
            }
            DispatchQueue.main.async {
                self?.shouldLayoutByKeyboard = false
                self?.navigationController?.pushViewController(withBackRoot: ConversationViewController.instance(conversation: conversation))
            }
        }
    }
    
    class func instance(members: [GroupUser]) -> UIViewController {
        let vc = Storyboard.group.instantiateViewController(withIdentifier: "new_group") as! NewGroupViewController
        vc.members = members
        return ContainerViewController.instance(viewController: vc, title: Localized.GROUP_NAVIGATION_TITLE_NEW_GROUP)
    }
    
}
