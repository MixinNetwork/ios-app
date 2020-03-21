import UIKit
import Photos
import MixinServices
import Rswift
import MobileCoreServices

class ShareRecipientViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchTextField: UITextField!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var loadingView: UIView!
    @IBOutlet weak var progressLabel: UILabel!

    private let queue = OperationQueue()
    private let initDataOperation = BlockOperation()
    private let headerReuseId = "header"

    private weak var timer: Timer?

    private var sectionTitles = [String]()
    private var conversations = [[RecipientSearchItem]]()
    private var searchResults = [RecipientSearchItem]()
    private var searchingKeyword: String?
    private var isSearching: Bool {
        return searchingKeyword != nil
    }
    private var exportSession: AssetExportSession?

    override func viewDidLoad() {
        super.viewDidLoad()

        guard LoginManager.shared.isLoggedIn else {
            cancelShareAction()
            return
        }

        cancelButton.setTitle(R.string.localizable.action_cancel(), for: .normal)
        searchTextField.placeholder = R.string.localizable.search_placeholder_contact()

        tableView.register(UINib(nibName: "RecipientHeaderView", bundle: nil), forHeaderFooterViewReuseIdentifier: headerReuseId)
        tableView.dataSource = self
        tableView.delegate = self
        searchTextField.addTarget(self, action: #selector(textFieldEditingChanged(_:)), for: .editingChanged)
        tableView.tableFooterView = UIView()
        initData()
    }

    deinit {
        stopTimer()
    }

    func initData() {
        initDataOperation.addExecutionBlock { [weak self] in
            let conversations = ConversationDAO.shared.conversationList().compactMap(RecipientSearchItem.init)
            let users = UserDAO.shared.contacts().map(RecipientSearchItem.init)
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }

                weakSelf.sectionTitles = []
                weakSelf.conversations = []
                if conversations.count > 0 {
                    weakSelf.sectionTitles.append(R.string.localizable.chat_forward_chats())
                    weakSelf.conversations.append(conversations)
                }
                if users.count > 0 {
                    weakSelf.sectionTitles.append(R.string.localizable.chat_forward_contacts())
                    weakSelf.conversations.append(users)
                }
                weakSelf.tableView.reloadData()
            }
        }
        queue.addOperation(initDataOperation)
    }

    @objc func textFieldEditingChanged(_ textField: UITextField) {
        let trimmedLowercaseKeyword = (textField.text ?? "")
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        guard !trimmedLowercaseKeyword.isEmpty else {
            searchingKeyword = nil
            tableView.reloadData()
            return
        }
        guard trimmedLowercaseKeyword != searchingKeyword else {
            return
        }
        search(keyword: trimmedLowercaseKeyword)
    }

    private func search(keyword: String) {
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

    @IBAction func cancelAction(_ sender: Any) {
        cancelShareAction()
    }

    private func cancelShareAction() {
        extensionContext?.cancelRequest(withError: NSError(domain: "Mixin", code: 401, userInfo: nil))
    }
}

extension ShareRecipientViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: RecipientCell.reuseIdentifier, for: indexPath) as! RecipientCell
        if isSearching {
            cell.render(conversation: searchResults[indexPath.row])
        } else {
            cell.render(conversation: conversations[indexPath.section][indexPath.row])
        }
        return cell
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return isSearching ? 1 : conversations.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? searchResults.count : conversations[section].count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard !isSearching, !sectionTitles.isEmpty, !sectionIsEmpty(section) else {
            return nil
        }
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerReuseId) as! RecipientHeaderView
        header.headerLabel.text = sectionTitles[section]
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if isSearching {
            return .leastNormalMagnitude
        } else if !sectionTitles.isEmpty {
            return sectionIsEmpty(section) ? .leastNormalMagnitude : 36
        } else {
            return .leastNormalMagnitude
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let conversation = isSearching ? searchResults[indexPath.row] : conversations[indexPath.section][indexPath.row]
        shareAction(conversation: conversation)
    }

    private func sectionIsEmpty(_ section: Int) -> Bool {
        return self.tableView(tableView, numberOfRowsInSection: section) == 0
    }
}


extension ShareRecipientViewController {

    private func shareAction(conversation: RecipientSearchItem) {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            return
        }

        view.endEditing(true)
        loadingView.isHidden = false

        let supportedTextUTIs = [kUTTypePlainText as String,
                                 kUTTypeText as String]
        let supportedImageUTI = kUTTypeImage as String
        let supportedPostUTIs = [kUTTypeSourceCode as String,
                                 kUTTypeScript as String,
                                 "dyn.age80s52"]    //golang
        let supportedFileUTI = kUTTypeFileURL as String

        let dispatchGroup = DispatchGroup()

        for extensionItem in extensionItems {
            guard let attachments = extensionItem.attachments else {
                continue
            }
            for attachment in attachments {
                if attachment.hasItemConformingToTypeIdentifier(kUTTypeMovie as String) {
                    progressLabel.text = "1%"
                    progressLabel.isHidden = false
                    dispatchGroup.enter()
                    attachment.loadItem(forTypeIdentifier: kUTTypeMovie as String, options: nil) { [weak self](item, error) in
                        if let err = error {
                            Logger.write(error: err)
                            dispatchGroup.leave()
                            return
                        }
                        guard let url = item as? URL else {
                            dispatchGroup.leave()
                            return
                        }
                        let messageId = UUID().uuidString.lowercased()
                        let videoFilename = messageId + ExtensionName.mp4.withDot
                        let videoUrl = AttachmentContainer.url(for: .videos, filename: videoFilename)
                        let asset = AVAsset(url: url)

                        let exportSession = AssetExportSession(asset: asset, outputURL: videoUrl)
                        exportSession.exportAsynchronously {
                            if exportSession.status == .completed {
                                self?.shareVideoMessage(url: videoUrl, conversation: conversation, messageId: messageId)
                            }
                            self?.stopTimer()
                            dispatchGroup.leave()
                        }
                        self?.exportSession = exportSession
                    }
                    stopTimer()
                    let timer = Timer(timeInterval: 1, repeats: true, block: { [weak self] (timer) in
                        guard let progress = self?.exportSession?.progress else {
                            self?.stopTimer()
                            return
                        }
                        var safeProgress = Int(progress * 100)
                        safeProgress = max(safeProgress, 1)
                        safeProgress = min(safeProgress, 100)
                        self?.progressLabel.text = "\(safeProgress)%"
                    })
                    RunLoop.main.add(timer, forMode: .common)
                    self.timer = timer
                } else {
                    guard let typeIdentifier = attachment.registeredTypeIdentifiers.first else {
                        continue
                    }

                    dispatchGroup.enter()
                    attachment.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { [weak self](item, error) in
                        defer {
                            dispatchGroup.leave()
                        }
                        if let err = error {
                            Logger.write(error: err)
                            return
                        }
                        guard let weakSelf = self else {
                            return
                        }

                        if supportedPostUTIs.contains(where: attachment.hasItemConformingToTypeIdentifier) {
                            guard let url = item as? URL else {
                                return
                            }
                            weakSelf.sharePostMessage(url: url, conversation: conversation)
                        } else if supportedTextUTIs.contains(where: attachment.hasItemConformingToTypeIdentifier) {
                            guard let content = item as? String else {
                                return
                            }
                            weakSelf.shareTextMessage(content: content, conversation: conversation)
                        } else if attachment.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                            guard let url = item as? URL else {
                                return
                            }
                            weakSelf.shareTextMessage(content: url.absoluteString, conversation: conversation)
                        } else if attachment.hasItemConformingToTypeIdentifier(kUTTypeMovie as String) {
                            guard let url = item as? URL else {
                                return
                            }
                            weakSelf.sharePhotoMessage(url: url, conversation: conversation, typeIdentifier: typeIdentifier as CFString)
                        } else {
                            guard let url = item as? URL else {
                                return
                            }
                            weakSelf.shareFileMessage(url: url, conversation: conversation)
                        }
                    }
                }
            }
        }

        dispatchGroup.notify(queue: .main) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func shareTextMessage(content: String, conversation: RecipientSearchItem) {
        let category: MessageCategory = conversation.isSignalConversation ? .SIGNAL_TEXT : .PLAIN_TEXT
        var message = Message.createMessage(category: category.rawValue, conversationId: conversation.conversationId, userId: myUserId)
        message.content = content
        sendMessage(message: message, conversation: conversation)
    }

    private func sharePostMessage(url: URL, conversation: RecipientSearchItem) {
        guard let data = try? Data(contentsOf: url), let content = String(data: data, encoding: .utf8) else {
            return
        }
        let category: MessageCategory = conversation.isSignalConversation ? .SIGNAL_POST : .PLAIN_POST
        var message = Message.createMessage(category: category.rawValue, conversationId: conversation.conversationId, userId: myUserId)
        message.content = "```\n\(content)\n```"
        sendMessage(message: message, conversation: conversation)
    }

    private func sharePhotoMessage(url: URL, conversation: RecipientSearchItem, typeIdentifier: CFString) {
        guard let image = UIImage(contentsOfFile: url.path) else {
            return
        }

        let category: MessageCategory = conversation.isSignalConversation ? .SIGNAL_IMAGE : .PLAIN_IMAGE
        var message = Message.createMessage(category: category.rawValue, conversationId: conversation.conversationId, userId: myUserId)
        let extensionName: String
        let imageData: Data?

        if UTTypeConformsTo(typeIdentifier, kUTTypeGIF) {
            extensionName = ExtensionName.gif.rawValue
            imageData = try? Data(contentsOf: url)
            message.mediaMimeType = "image/gif"
        } else {
            extensionName = ExtensionName.jpeg.rawValue
            imageData = image.scaleForUpload().jpegData(compressionQuality: 0.75)
            message.mediaMimeType = "image/jpeg"
        }

        guard let data = imageData, let targetImage = UIImage(data: data) else {
            return
        }

        let filename = "\(message.messageId).\(extensionName)"
        let url = AttachmentContainer.url(for: .photos, filename: filename)
        message.thumbImage = targetImage.base64Thumbnail()

        do {
            try data.write(to: url)
        } catch {
            reporter.report(error: error)
            return
        }

        message.mediaStatus = MediaStatus.PENDING.rawValue
        message.mediaWidth = Int(targetImage.size.width)
        message.mediaHeight = Int(targetImage.size.height)
        message.mediaUrl = url.lastPathComponent
        sendMessage(message: message, conversation: conversation)
    }

    private func shareVideoMessage(url: URL, conversation: RecipientSearchItem, messageId: String) {
        let asset = AVAsset(url: url)
        guard asset.duration.isValid, let videoTrack = asset.tracks(withMediaType: .video).first else {
            return
        }
        guard let thumbnail = UIImage(withFirstFrameOfVideoAtURL: url) else {
            return
        }
        let thumbnailURL = AttachmentContainer.url(for: .videos, filename: messageId + ExtensionName.jpeg.withDot)
        thumbnail.saveToFile(path: thumbnailURL)

        let category: MessageCategory = conversation.isSignalConversation ? .SIGNAL_VIDEO : .SIGNAL_VIDEO
        var message = Message.createMessage(category: category.rawValue, conversationId: conversation.conversationId, userId: myUserId)
        message.messageId = messageId
        message.thumbImage = thumbnail.base64Thumbnail()
        message.mediaDuration = Int64(asset.duration.seconds * millisecondsPerSecond)
        let size = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
        message.mediaWidth = Int(abs(size.width))
        message.mediaHeight = Int(abs(size.height))
        message.mediaSize = FileManager.default.fileSize(url.path)
        message.mediaMimeType = FileManager.default.mimeType(ext: url.pathExtension)
        message.mediaUrl = url.lastPathComponent
        message.mediaStatus = MediaStatus.PENDING.rawValue
        sendMessage(message: message, conversation: conversation)
    }

    private func shareFileMessage(url: URL, conversation: RecipientSearchItem) {
        guard FileManager.default.fileSize(url.path) > 0 else {
            return
        }
        let category: MessageCategory = conversation.isSignalConversation ? .SIGNAL_DATA : .SIGNAL_DATA
        var message = Message.createMessage(category: category.rawValue, conversationId: conversation.conversationId, userId: myUserId)

        let fileExtension = url.pathExtension.lowercased()
        let fileUrl = AttachmentContainer.url(for: .files, filename: "\(message.messageId).\(fileExtension)")
        do {
            try FileManager.default.copyItem(at: url, to: fileUrl)
        } catch {
            reporter.report(error: error)
            return
        }

        message.name = url.lastPathComponent
        message.mediaSize = FileManager.default.fileSize(fileUrl.path)
        message.mediaMimeType = FileManager.default.mimeType(ext: fileExtension)
        message.mediaUrl = fileUrl.lastPathComponent
        message.mediaStatus = MediaStatus.PENDING.rawValue
        sendMessage(message: message, conversation: conversation)
    }

    private func sendMessage(message: Message, conversation: RecipientSearchItem) {
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

}
