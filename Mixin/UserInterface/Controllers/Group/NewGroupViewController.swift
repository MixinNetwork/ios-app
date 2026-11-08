import UIKit
import MixinServices

final class NewGroupViewController: UIViewController {
    
    @IBOutlet weak var groupImageView: CornerImageView!
    @IBOutlet weak var participentLabel: UILabel!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var expirationLabel: UILabel!
    @IBOutlet weak var expirationButton: UIButton!
    @IBOutlet weak var createButton: RoundedButton!
    
    private let randomID = UUID().uuidString.lowercased()
    private let members: [GroupMemberCandidate]
    
    private var expirationDuration = Conversation.defaultExpirationDuration
    
    private var groupName: String {
        nameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    init(members: [GroupMemberCandidate]) {
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
        expirationLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        expirationLabel.text = R.string.localizable.disappearing_message()
        expirationButton.showsMenuAsPrimaryAction = true
        updateExpirationMenu()
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
        
        // TODO: Create the conversation with a serializable job, which encodes the random id
        let participants = members.map {
            ParticipantRequest(userId: $0.userId, role: "")
        }
        let conversationID = Self.groupConversationID(
            ownerID: myUserId,
            groupName: groupName,
            participantUserIDs: participants.map(\.userId),
            randomID: randomID
        )
        let request = ConversationRequest(
            conversationId: conversationID,
            name: groupName,
            category: ConversationCategory.GROUP.rawValue,
            participants: participants,
            duration: expirationDuration == 0 ? nil : expirationDuration,
            announcement: nil,
            randomID: randomID
        )
        ConversationAPI.createConversation(conversation: request) { [weak self](result) in
            guard let weakSelf = self else {
                return
            }
            switch result {
            case let .success(response):
                weakSelf.saveConversation(response: response)
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
                weakSelf.createButton.isBusy = false
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
    
    static func groupConversationID(
        ownerID: String,
        groupName: String,
        participantUserIDs: [String],
        randomID: String
    ) -> String {
        var id = UUID.uniqueObjectIDString(sorting: [ownerID, groupName])
        id = UUID.uniqueObjectIDString(sorting: [id, randomID])
        let sortedParticipantIDs = participantUserIDs.sorted()
        for participantID in sortedParticipantIDs {
            id = UUID.uniqueObjectIDString(sorting: [id, participantID])
        }
        return id
    }
    
    private func updateExpirationMenu() {
        expirationButton.configuration?.attributedTitle = AttributedString(
            string: ExpiredMessageDurationFormatter.string(from: expirationDuration),
            scalingByFontSize: 14
        )
        let selectedOption = MessageExpirationDurationViewController.Option(expireIn: expirationDuration)
        let actions = MessageExpirationDurationViewController.Option.allCases.map { option in
            let title = option == .custom ? R.string.localizable.custom() : option.title
            return UIAction(title: title, state: option == selectedOption ? .on : .off) { [weak self] _ in
                guard let self else {
                    return
                }
                if let duration = option.expireIn {
                    self.expirationDuration = duration
                    self.updateExpirationMenu()
                } else {
                    self.nameTextField.resignFirstResponder()
                    let picker = CustomMessageExpirationDurationPickerViewController(
                        expireIn: self.expirationDuration,
                        onPick: { [weak self] duration in
                            self?.expirationDuration = duration
                            self?.updateExpirationMenu()
                        },
                    )
                    self.present(picker, animated: true)
                }
            }
        }
        expirationButton.menu = UIMenu(children: actions)
    }
    
    private func loadGroupIcon() {
        var members = self.members
        if let account = LoginManager.shared.account {
            let me = GroupMemberCandidate(account: account)
            members.insert(me, at: 0)
        }
        DispatchQueue.global().async { [weak self] in
            let groupImage = GroupIconMaker.make(participants: members)
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
            let filename = try GroupIconSaver.save(
                image: image,
                forGroupWith: conversationId,
                participants: participants
            )
            guard ConversationDAO.shared.updateGeneratedGroupIcon(conversationID: conversationId, filename: filename) else {
                try? FileManager.default.removeItem(at: AppGroupContainer.groupIconsUrl.appendingPathComponent(filename))
                return nil
            }
            return filename
        } catch let GroupIconSaver.Error.fileExists(filename) {
            return ConversationDAO.shared.updateGeneratedGroupIcon(conversationID: conversationId, filename: filename) ? filename : nil
        } catch {
            reporter.report(error: error)
            return nil
        }
    }
    
    private func saveConversation(response: ConversationResponse) {
        DispatchQueue.global().async { [weak self] in
            let (conversation, participantUsers) = ConversationDAO.shared.createNewConversation(response: response)
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                if response.iconUrl.isEmpty {
                    let iconURL = weakSelf.saveGroupImage(
                        conversationId: conversation.conversationId,
                        participants: participantUsers,
                    )
                    if let iconURL {
                        conversation.iconUrl = iconURL
                    }
                }
                weakSelf.nameTextField.resignFirstResponder()
                let vc = ConversationViewController.instance(conversation: conversation)
                weakSelf.navigationController?.pushViewController(afterRoot: vc)
            }
        }
    }
    
}
