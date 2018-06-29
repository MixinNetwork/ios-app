import UIKit

class ForwardViewController: UIViewController {

    @IBOutlet weak var keywordTextField: UITextField!
    @IBOutlet weak var tableView: UITableView!

    internal typealias Section = [ForwardUser]
    private let headerReuseId = "Header"

    private var isSearching: Bool {
        return !(keywordTextField.text ?? "").isEmpty
    }
    internal var sections = [Section]()
    private var searchResult = [ForwardUser]()
    private var message: MessageItem!
    internal var ownerUser: UserItem?

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UINib(nibName: "ContactCell", bundle: nil), forCellReuseIdentifier: ContactCell.cellIdentifier)
        tableView.register(GeneralTableViewHeader.self, forHeaderFooterViewReuseIdentifier: headerReuseId)
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
        keywordTextField.delegate = self
        fetchData()
    }

    internal func fetchData() {
        DispatchQueue.global().async { [weak self] in
            let conversations = ConversationDAO.shared.getForwardConversations()
            let contacts = UserDAO.shared.getForwardContacts()

            guard let weakSelf = self else {
                return
            }
            if conversations.count > 0 {
                weakSelf.sections.append(conversations)
            }
            if contacts.count > 0 {
                weakSelf.sections.append(contacts)
            }
            DispatchQueue.main.async {
                weakSelf.tableView.reloadData()
            }
        }
    }

    @IBAction func searchAction(_ sender: Any) {
        let keyword = (keywordTextField.text ?? "").uppercased()
        if keyword.isEmpty {
            searchResult = []
        } else {
            searchResult = sections.flatMap({ $0 }).filter({ $0.fullName.uppercased().contains(keyword) || (!$0.name.isEmpty && $0.name.uppercased().contains(keyword)) })
        }
        tableView.reloadData()
    }

    func forwardMessage(_ targetUser: ForwardUser) {
        let oldConversationId = message.conversationId

        var newMessage = Message.createMessage(category: message.category, conversationId: targetUser.conversationId, userId: AccountAPI.shared.accountUserId)
        if message.category.hasSuffix("_TEXT") {
            newMessage.content = message.content
        } else if message.category.hasSuffix("_IMAGE") {
            newMessage.thumbImage = message.thumbImage
            newMessage.mediaSize = message.mediaSize
            newMessage.mediaWidth = message.mediaWidth
            newMessage.mediaHeight = message.mediaHeight
            newMessage.mediaMimeType = message.mediaMimeType
            newMessage.mediaUrl = message.mediaUrl
            newMessage.mediaStatus = MediaStatus.PENDING.rawValue
        } else if message.category.hasSuffix("_DATA") {
            newMessage.name = message.name
            newMessage.mediaSize = message.mediaSize
            newMessage.mediaMimeType = message.mediaMimeType
            newMessage.mediaUrl = message.mediaUrl
            newMessage.mediaStatus = MediaStatus.PENDING.rawValue
        } else if message.category.hasSuffix("_AUDIO") {
            newMessage.mediaSize = message.mediaSize
            newMessage.mediaMimeType = message.mediaMimeType
            newMessage.mediaUrl = message.mediaUrl
            newMessage.mediaWaveform = message.mediaWaveform
            newMessage.mediaDuration = message.mediaDuration
            newMessage.mediaStatus = MediaStatus.PENDING.rawValue
        } else if message.category.hasSuffix("_VIDEO") {
            newMessage.thumbImage = message.thumbImage
            newMessage.mediaSize = message.mediaSize
            newMessage.mediaWidth = message.mediaWidth
            newMessage.mediaHeight = message.mediaHeight
            newMessage.mediaMimeType = message.mediaMimeType
            newMessage.mediaUrl = message.mediaUrl
            newMessage.mediaStatus = MediaStatus.PENDING.rawValue
            newMessage.mediaDuration = message.mediaDuration
        } else if message.category.hasSuffix("_STICKER") {
            guard let stickerId = message.stickerId, let sticker = StickerDAO.shared.getSticker(stickerId: stickerId), let albumId = AlbumDAO.shared.getAlbum(stickerId: sticker.stickerId)?.albumId else {
                return
            }

            newMessage.mediaUrl = message.mediaUrl
            newMessage.stickerId = message.stickerId
            newMessage.mediaStatus = MediaStatus.PENDING.rawValue
            let transferData = TransferStickerData(stickerId: sticker.stickerId, name: sticker.name, albumId: albumId)
            newMessage.content = try! JSONEncoder().encode(transferData).base64EncodedString()
        } else if message.category.hasSuffix("_CONTACT") {
            guard let sharedUserId = message.sharedUserId else {
                return
            }
            newMessage.sharedUserId = sharedUserId
            let transferData = TransferContactData(userId: sharedUserId)
            newMessage.content = try! JSONEncoder().encode(transferData).base64EncodedString()
        }
        DispatchQueue.global().async { [weak self] in
            SendMessageService.shared.sendMessage(message: newMessage, ownerUser: targetUser.toUser(), isGroupMessage: targetUser.isGroup)
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                if !weakSelf.message.conversationId.isEmpty && targetUser.conversationId == oldConversationId {
                    weakSelf.navigationController?.popViewController(animated: true)
                } else {
                    weakSelf.gotoConversationVC(targetUser)
                }
            }
        }
    }

    internal func gotoConversationVC(_ targetUser: ForwardUser) {
        if targetUser.conversationId.isEmpty {
            navigationController?.pushViewController(withBackRoot: ConversationViewController.instance(ownerUser: targetUser.toUser()))
        } else {
            navigationController?.pushViewController(withBackRoot: ConversationViewController.instance(conversation: targetUser.toConversation()))
        }
    }

    class func instance(message: MessageItem, ownerUser: UserItem?) -> UIViewController {
        let vc = Storyboard.chat.instantiateViewController(withIdentifier: "forward") as! ForwardViewController
        vc.message = message
        vc.ownerUser = ownerUser
        return ContainerViewController.instance(viewController: vc, title: Localized.CHAT_FORWARD_TITLE)
    }
}

extension ForwardViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard sections.count > 0 else {
            return 0
        }
        return isSearching ? searchResult.count : sections[section].count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ContactCell.cellIdentifier) as! ContactCell
        let user: ForwardUser
        if isSearching {
            user = searchResult[indexPath.row]
        } else {
            user = sections[indexPath.section][indexPath.row]
        }
        cell.render(user: user)
        return cell
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return isSearching ? 1 : sections.count
    }

}

extension ForwardViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if isSearching {
            return nil
        } else {
            let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerReuseId) as! GeneralTableViewHeader
            if section == 0 && !sections[section][0].category.isEmpty {
                header.label.text = Localized.CHAT_FORWARD_CHATS
            } else {
                header.label.text = Localized.CHAT_FORWARD_CONTACTS
            }
            return header
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return isSearching ? .leastNormalMagnitude : 30
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isSearching {
            forwardMessage(searchResult[indexPath.row])
        } else {
            forwardMessage(sections[indexPath.section][indexPath.row])
        }
    }
}

extension ForwardViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        keywordTextField.text = nil
        keywordTextField.resignFirstResponder()
        tableView.reloadData()
        return false
    }

}


struct ForwardUser {
    let name: String
    let iconUrl: String
    let userId: String
    let identityNumber: String
    let fullName: String
    let ownerAvatarUrl: String
    let ownerAppId: String?
    let ownerIsVerified: Bool
    let category: String
    let conversationId: String
    var isGroup: Bool {
        return category == ConversationCategory.GROUP.rawValue
    }
    var isBot: Bool {
        guard let ownerAppId = self.ownerAppId else {
            return false
        }
        return !ownerAppId.isEmpty
    }

    func toConversation() -> ConversationItem {
        let conversation = ConversationItem()
        conversation.conversationId = conversationId
        conversation.name = name
        conversation.ownerId = userId
        conversation.category = category
        conversation.iconUrl = iconUrl
        conversation.ownerFullName = fullName
        conversation.ownerIdentityNumber = identityNumber
        conversation.ownerAvatarUrl = ownerAvatarUrl
        conversation.ownerId = userId
        conversation.ownerIsVerified = ownerIsVerified
        conversation.appId = ownerAppId
        conversation.status = ConversationStatus.SUCCESS.rawValue
        return conversation
    }

    func toUser() -> UserItem {
        return UserItem.createUser(userId: userId, fullName: fullName, identityNumber: identityNumber, avatarUrl: ownerAvatarUrl, appId: ownerAppId)
    }
}
