import UIKit
import Social
import MixinServices
import Rswift
import MobileCoreServices

class ShareViewController: UITableViewController {

    private let queue = OperationQueue()
    private let initDataOperation = BlockOperation()
    private let headerReuseId = "header"

    private var searchingKeyword: String?
    private var isSearching: Bool {
        return searchingKeyword != nil
    }
    private var sectionTitles = [R.string.localizable.chat_forward_chats(), R.string.localizable.chat_forward_contacts()]
    private var conversations = [[ConversationSearchItem]]()

    private var searchResults = [ConversationSearchItem]()

    override func viewDidLoad() {
        super.viewDidLoad()

        guard LoginManager.shared.isLoggedIn else {
            cancelShareAction()
            return
        }

        tableView.register(UINib(resource: R.nib.conversationHeaderView), forHeaderFooterViewReuseIdentifier: headerReuseId)
        tableView.dataSource = self
        tableView.delegate = self
        initData()
    }

    func initData() {
        initDataOperation.addExecutionBlock { [weak self] in
            let conversations = ConversationDAO.shared.conversationList().compactMap(ConversationSearchItem.init)
            let users = UserDAO.shared.contacts().map(ConversationSearchItem.init)
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                weakSelf.conversations = [conversations, users]
                weakSelf.tableView.reloadData()
            }
        }
        queue.addOperation(initDataOperation)
    }

    func search(keyword: String) {
        queue.operations
            .filter({ $0 != initDataOperation })
            .forEach({ $0.cancel() })
        let op = BlockOperation()
        let receivers = self.conversations
        op.addExecutionBlock { [unowned op, weak self] in
            guard self != nil, !op.isCancelled else {
                return
            }
            let uniqueReceivers = Set(receivers.flatMap({ $0 }))
            let searchResults = uniqueReceivers
                .filter { $0.matches(lowercasedKeyword: keyword) }
                .map { $0 }
            DispatchQueue.main.sync {
                guard let weakSelf = self, !op.isCancelled else {
                    return
                }
                weakSelf.searchingKeyword = keyword
                weakSelf.searchResults = searchResults
                weakSelf.tableView.reloadData()
            }
        }
        queue.addOperation(op)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ConversationCell.reuseIdentifier, for: indexPath) as! ConversationCell
        if isSearching {
            cell.render(conversation: searchResults[indexPath.row])
        } else {
            cell.render(conversation: conversations[indexPath.section][indexPath.row])
        }
        return cell
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return isSearching ? 1 : conversations.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? searchResults.count : conversations[section].count
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard !isSearching, !sectionTitles.isEmpty, !sectionIsEmpty(section) else {
            return nil
        }
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerReuseId) as! ConversationHeaderView
        header.headerLabel.text = sectionTitles[section]
        return header
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if isSearching {
            return .leastNormalMagnitude
        } else if !sectionTitles.isEmpty {
            return sectionIsEmpty(section) ? .leastNormalMagnitude : 36
        } else {
            return .leastNormalMagnitude
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let conversation = isSearching ? searchResults[indexPath.row] : conversations[indexPath.section][indexPath.row]
        shareAction(conversation: conversation)
    }

    private func sectionIsEmpty(_ section: Int) -> Bool {
        return self.tableView(tableView, numberOfRowsInSection: section) == 0
    }

    private func shareAction(conversation: ConversationSearchItem) {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            return
        }

        let imageIdentifier = kUTTypeImage as String
        let urlIdentifier = kUTTypeURL as String
        let movieIdentifier = kUTTypeMovie as String

        for extensionItem in extensionItems {
            guard let attachments = extensionItem.attachments else {
                continue
            }
            for attachment in attachments {
                if attachment.hasItemConformingToTypeIdentifier(imageIdentifier) {

                } else if attachment.hasItemConformingToTypeIdentifier(urlIdentifier) {

                } else if attachment.hasItemConformingToTypeIdentifier(movieIdentifier) {

                }
            }
        }
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func sendMessage(message: Message, conversation: ConversationSearchItem) {
        guard LoginManager.shared.isLoggedIn else {
            cancelShareAction()
            return
        }
        var msg = message
        msg.userId = myUserId
        msg.status = MessageStatus.SENDING.rawValue

        if !ConversationDAO.shared.isExist(conversationId: msg.conversationId) {
            guard conversation.category == ConversationCategory.CONTACT.rawValue else  {
                cancelShareAction()
                return
            }

            ConversationDAO.shared.createConversation(conversation: ConversationResponse(conversationId: conversation.conversationId, userId: conversation.userId, avatarUrl: conversation.avatarUrl), targetStatus: .START)
        }

        if msg.category.hasSuffix("_TEXT"), let content = msg.content, content.utf8.count > 64 * 1024 {
            msg.content = String(content.prefix(64 * 1024))
        }
        MessageDAO.shared.insertMessage(message: msg, messageSource: "")

        if msg.category.hasSuffix("_TEXT") {
            SendMessageService.shared.sendMessage(message: msg, data: msg.content, immediatelySend: false)
        } else if ["_IMAGE", "_VIDEO", "_DATA"].contains(where: msg.category.hasSuffix) {
            SendMessageService.shared.saveUploadJob(message: msg)
        }
    }

    private func cancelShareAction() {
        extensionContext?.cancelRequest(withError: NSError(domain: "Mixin", code: 401, userInfo: nil))
    }
}
