import UIKit
import Alamofire
import SwiftMessages

class DAppGroupView: UIStackView {
    
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    @IBOutlet weak var participantsLabel: UILabel!
    @IBOutlet weak var participantsCollectionView: UICollectionView!
    @IBOutlet weak var joinGroupButton: StateResponsiveButton!
    @IBOutlet weak var viewGroupButton: StateResponsiveButton!

    private let participantCellReuseId = "ParticipantCell"
    
    private var conversation: ConversationResponse!
    private var codeId = ""
    private var participants = [UserResponse]()

    private weak var joinConversationRequest: Request?
    private weak var superView: BottomSheetView?

    override func awakeFromNib() {
        super.awakeFromNib()
        self.roundCorners(cornerRadius: 8)
        participantsCollectionView.register(UINib(nibName: "GroupParticipantCell", bundle: .main),
                                            forCellWithReuseIdentifier: participantCellReuseId)
        participantsCollectionView.dataSource = self
    }

    func render(codeId: String, conversation: ConversationResponse, ownerUser: UserItem, participants: [UserResponse], alreadyInTheGroup: Bool, superView: BottomSheetView) {
        self.superView = superView
        self.participants = participants
        self.conversation = conversation
        self.codeId = codeId

        participantsLabel.text = Localized.GROUP_SECTION_TITLE_MEMBERS(count: conversation.participants.count)
        iconImageView.image = #imageLiteral(resourceName: "ic_conversation_group")
        nameLabel.text = conversation.name

        let fullName = ownerUser.userId == AccountAPI.shared.accountUserId ? Localized.CHAT_MESSAGE_YOU : ownerUser.fullName
        detailLabel.text = Localized.CHAT_MESSAGE_CREATED(fullName: fullName)

        participantsCollectionView.reloadData()
        joinGroupButton.isHidden = alreadyInTheGroup
        viewGroupButton.isHidden = !alreadyInTheGroup
    }

    @IBAction func joinAction(_ sender: Any) {
        guard !joinGroupButton.isBusy else {
            return
        }
        joinGroupButton.isBusy = true
        joinConversationRequest = ConversationAPI.shared.joinConversation(codeId: codeId) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            switch result {
            case .success(let response):
                weakSelf.saveConversation(conversation: response)
            case let .failure(error, _):
                weakSelf.joinGroupButton.isBusy = false
                SwiftMessages.showToast(message: error.kind.localizedDescription ?? Localized.TOAST_OPERATION_FAILED, backgroundColor: .hintRed)
            }
        }
    }
    
    @IBAction func viewAction(_ sender: Any) {
        guard !viewGroupButton.isBusy else {
            return
        }
        viewGroupButton.isBusy = true
        saveConversation(conversation: conversation)
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        superView?.dismissPopupControllerAnimated()
    }

    private func saveConversation(conversation: ConversationResponse) {
        DispatchQueue.global().async { [weak self] in
            guard ConversationDAO.shared.createConversation(conversation: conversation, targetStatus: .SUCCESS) else {
                self?.superView?.dismissPopupControllerAnimated()
                return
            }
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }

                let vc = ConversationViewController.instance(conversation: ConversationItem.createConversation(from: conversation))
                UIApplication.currentActivity()?.navigationController?.pushViewController(withBackRoot: vc)
                weakSelf.superView?.dismissPopupControllerAnimated()
            }
        }
    }
    
    class func instance() -> DAppGroupView {
        return Bundle.main.loadNibNamed("DAppGroupView", owner: nil, options: nil)?.first as! DAppGroupView
    }
    
}

extension DAppGroupView: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return participants.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: participantCellReuseId, for: indexPath) as! GroupParticipantCell
        let user = participants[indexPath.row]
        cell.imageView.setImage(user: user)
        cell.label.text = user.fullName
        return cell
    }
    
}
