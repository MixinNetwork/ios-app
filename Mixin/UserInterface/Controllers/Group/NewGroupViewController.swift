import UIKit
import MixinServices

final class NewGroupViewController: UIViewController {
    
    @IBOutlet weak var groupImageView: CornerImageView!
    @IBOutlet weak var participentLabel: UILabel!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var createButton: RoundedButton!
    
    private let conversationId = UUID().uuidString.lowercased()
    private let members: [GroupUser]
    
    private var groupName: String {
        nameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    init(members: [GroupUser]) {
        self.members = members
        let nib = R.nib.newGroupView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.new_group()
        loadGroupIcon()
        nameTextField.delegate = self
        participentLabel.text = R.string.localizable.title_participants_count(members.count + 1)
        createButton.snp.makeConstraints { make in
            make.bottom.equalTo(view.keyboardLayoutGuide.snp.top)
                .offset(-20)
                .priority(.high)
        }
        nameTextField.becomeFirstResponder()
    }
    
    @IBAction func updateCreateButton(_ sender: Any) {
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
    
}

extension NewGroupViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
}

extension NewGroupViewController {
    
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
                weakSelf.nameTextField.resignFirstResponder()
                let vc = ConversationViewController.instance(conversation: conversation)
                weakSelf.navigationController?.pushViewController(withBackRoot: vc)
            }
        }
    }
    
}
