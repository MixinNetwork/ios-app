import UIKit

class ContactConversationExtensionViewController: UIViewController, ConversationExtensionViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    private let cellReuseId = "contact"
    
    private var contacts = [UserItem]()
    
    private var selectedIndexPaths: [IndexPath] {
        return collectionView.indexPathsForSelectedItems ?? []
    }
    
    var canBeFullsized: Bool {
        return true
    }
    
    static func instance() -> ContactConversationExtensionViewController {
        return Storyboard.chat.instantiateViewController(withIdentifier: "extension_contact") as! ContactConversationExtensionViewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
        DispatchQueue.global().async { [weak self] in
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
    }
    
    private func removeAllSelection() {
        for indexPath in selectedIndexPaths {
            collectionView.deselectItem(at: indexPath, animated: true)
        }
    }
    
}

extension ContactConversationExtensionViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return contacts.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseId, for: indexPath) as! ContactConversationExtensionCell
        let contact = contacts[indexPath.row]
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
            send(contact: contacts[indexPath.row])
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
