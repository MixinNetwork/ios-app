import UIKit

class ContactConversationExtensionViewController: UIViewController {
    
    @IBOutlet weak var searchTextField: UITextField!
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var showSearchBarConstraint: NSLayoutConstraint!
    @IBOutlet weak var hideSearchBarConstraint: NSLayoutConstraint!
    
    private let cellReuseId = "contact"
    private let queue = OperationQueue()
    private let searchIconView: UIView = {
        let leftMargin: CGFloat = 12
        let rightMargin: CGFloat = 8
        let icon = UIImage(named: "ic_search")!
        let imageView = UIImageView(image: icon)
        imageView.contentMode = .right
        imageView.frame = CGRect(x: leftMargin, y: 0, width: icon.size.width, height: icon.size.height)
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        let view = UIView(frame: CGRect(x: 0, y: 0, width: icon.size.width + leftMargin + rightMargin, height: icon.size.height))
        view.addSubview(imageView)
        return view
    }()
    
    private var contacts = [UserItem]()
    private var searchResults = [UserItem]()
    private var lastKeyword = ""
    
    private var keyword: String {
        return (searchTextField.text ?? "")
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var isSearching: Bool {
        return !keyword.isEmpty
    }
    
    private var selectedIndexPaths: [IndexPath] {
        return collectionView.indexPathsForSelectedItems ?? []
    }
    
    static func instance() -> ContactConversationExtensionViewController {
        return Storyboard.chat.instantiateViewController(withIdentifier: "extension_contact") as! ContactConversationExtensionViewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchTextField.leftView = searchIconView
        searchTextField.leftViewMode = .always
        collectionView.dataSource = self
        collectionView.delegate = self
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapAction(_:)))
        let backgroundView = UIView(frame: collectionView.bounds)
        backgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundView.addGestureRecognizer(tapRecognizer)
        collectionView.backgroundView = backgroundView
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            if ScreenSize.isCompactWidth {
                layout.sectionInset.left = 17
                layout.sectionInset.right = 17
            } else if ScreenSize.isPlusWidth {
                layout.sectionInset.left = 32
                layout.sectionInset.right = 32
            }
        }
        queue.addOperation { [weak self] in
            let contacts = UserDAO.shared.contacts()
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                weakSelf.contacts = contacts
                weakSelf.collectionView.reloadData()
            }
        }
    }
    
    @objc func tapAction(_ sender: UITapGestureRecognizer) {
        removeAllSelection()
    }
    
    @IBAction func searchAction(_ sender: Any) {
        let keyword = self.keyword
        let contacts = self.contacts
        guard searchTextField.markedTextRange == nil else {
            if collectionView.isDragging {
                collectionView.reloadData()
            }
            return
        }
        guard !keyword.isEmpty else {
            collectionView.reloadData()
            lastKeyword = ""
            return
        }
        guard keyword != lastKeyword else {
            return
        }
        lastKeyword = keyword
        queue.cancelAllOperations()
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op, weak self] in
            guard !op.isCancelled else {
                return
            }
            let result = contacts.filter({ (user) -> Bool in
                user.fullName.lowercased().contains(keyword)
            })
            DispatchQueue.main.sync {
                guard !op.isCancelled, let weakSelf = self else {
                    return
                }
                guard weakSelf.keyword == keyword else {
                    return
                }
                weakSelf.searchResults = result
                weakSelf.collectionView.reloadData()
            }
        }
        queue.addOperation(op)
    }
    
    private func send(contact: UserItem) {
        guard let conversationViewController = conversationViewController else {
            return
        }
        let conversation = conversationViewController.dataSource.conversation
        var message = Message.createMessage(category: MessageCategory.SIGNAL_CONTACT.rawValue,
                                            conversationId: conversation.conversationId,
                                            userId: AccountAPI.shared.accountUserId)
        message.sharedUserId = contact.userId
        let transferData = TransferContactData(userId: contact.userId)
        message.content = try! JSONEncoder().encode(transferData).base64EncodedString()
        SendMessageService.shared.sendMessage(message: message,
                                              ownerUser: conversationViewController.ownerUser,
                                              isGroupMessage: conversation.isGroup())
        conversationViewController.reduceBottomPanelSizeIfFullSized()
    }
    
    private func removeAllSelection() {
        for indexPath in selectedIndexPaths {
            collectionView.deselectItem(at: indexPath, animated: true)
        }
    }
    
}

extension ContactConversationExtensionViewController: ConversationExtensionViewController {
    
    var canBeFullsized: Bool {
        return true
    }
    
    func layoutForFullsized(_ fullsized: Bool) {
        if fullsized {
            showSearchBarConstraint.priority = .defaultHigh
            hideSearchBarConstraint.priority = .defaultLow
        } else {
            searchTextField.text = nil
            collectionView.reloadData()
            showSearchBarConstraint.priority = .defaultLow
            hideSearchBarConstraint.priority = .defaultHigh
        }
    }
    
}

extension ContactConversationExtensionViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return isSearching ? searchResults.count : contacts.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseId, for: indexPath) as! ContactConversationExtensionCell
        let contact = isSearching ? searchResults[indexPath.row] : contacts[indexPath.row]
        cell.avatarImageView.setImage(with: contact)
        cell.nameLabel.text = contact.fullName
        return cell
    }
    
}

extension ContactConversationExtensionViewController: UIScrollViewDelegate {
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        AppDelegate.current.window?.endEditing(true)
        removeAllSelection()
    }
    
}

extension ContactConversationExtensionViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if selectedIndexPaths.contains(indexPath) {
            removeAllSelection()
            let contact = isSearching ? searchResults[indexPath.row] : contacts[indexPath.row]
            send(contact: contact)
            return false
        } else {
            if selectedIndexPaths.isEmpty {
                return true
            } else {
                removeAllSelection()
                return false
            }
        }
    }
    
}
