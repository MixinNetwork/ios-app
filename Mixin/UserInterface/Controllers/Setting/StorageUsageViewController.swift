import Foundation
import UIKit
import MixinServices

class StorageUsageCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!
    
}

class StorageUsageViewController: UITableViewController {
    
    @IBOutlet weak var storageLabel: UILabel!
    
    private var conversations = [ConversationStorageUsage]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView()
        fetchConversations()
        NotificationCenter.default.addObserver(self, selector: #selector(fetchConversations), name: .StorageUsageDidChange, object: nil)
    }
    
    @objc func fetchConversations() {
        DispatchQueue.global().async { [weak self] in
            let conversations = ConversationDAO.shared.storageUsageConversations()
            DispatchQueue.main.async {
                self?.conversations = conversations
                self?.tableView.reloadData()
            }
        }
    }
    
    class func instance() -> UIViewController {
        let vc = R.storyboard.setting.storage()!
        let container = ContainerViewController.instance(viewController: vc, title: Localized.SETTING_STORAGE_USAGE)
        return container
    }
    
}

extension StorageUsageViewController {
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "storage_usage", for: indexPath) as! StorageUsageCell
        let conversation = conversations[indexPath.row]
        if conversation.category == ConversationCategory.CONTACT.rawValue {
            cell.avatarImageView.setImage(with: conversation.ownerAvatarUrl, userId: conversation.ownerId, name: conversation.ownerFullName)
        } else {
            cell.avatarImageView.setGroupImage(with: conversation.iconUrl)
        }
        cell.nameLabel.text = conversation.getConversationName()
        cell.sizeLabel.text = VideoMessageViewModel.byteCountFormatter.string(fromByteCount: conversation.mediaSize)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        navigationController?.pushViewController(ClearStorageViewController.instance(conversation: conversations[indexPath.row]), animated: true)
    }
    
}
