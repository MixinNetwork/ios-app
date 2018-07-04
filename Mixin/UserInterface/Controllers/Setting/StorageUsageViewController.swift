import Foundation
import UIKit

class StorageUsageViewController: UITableViewController {

    @IBOutlet weak var storageLabel: UILabel!

    private var conversations = [ConversationStorageUsage]()

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.tableFooterView = UIView()
        fetchConversations()

        NotificationCenter.default.addObserver(forName: .StorageUsageDidChange, object: nil, queue: .main) { [weak self] (_) in
            self?.fetchConversations()
        }
    }

    private func fetchConversations() {
        DispatchQueue.global().async { [weak self] in
            let conversations = ConversationDAO.shared.storageUsageConversations()

            DispatchQueue.main.async {
                self?.conversations = conversations
                self?.tableView.reloadData()
            }
        }
    }

    class func instance() -> UIViewController {
        let container = ContainerViewController.instance(viewController: Storyboard.setting.instantiateViewController(withIdentifier: "storage"), title: Localized.SETTING_STORAGE_USAGE)
        container.automaticallyAdjustsScrollViewInsets = false
        return container
    }
}

class StorageUsageCell: UITableViewCell {

    static let cellIdentifier = "cell_identifier_storage_usage"

    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!

    override func layoutSubviews() {
        super.layoutSubviews()
        separatorInset.left = nameLabel.frame.origin.x
    }

}

extension StorageUsageViewController {

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: StorageUsageCell.cellIdentifier, for: indexPath) as! StorageUsageCell
        let conversation = conversations[indexPath.row]
        if conversation.category == ConversationCategory.CONTACT.rawValue {
            cell.avatarImageView.setImage(with: conversation.ownerAvatarUrl, identityNumber: conversation.ownerIdentityNumber, name: conversation.ownerFullName)
        } else {
            cell.avatarImageView.setGroupImage(with: conversation.iconUrl, conversationId: conversation.conversationId)
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
