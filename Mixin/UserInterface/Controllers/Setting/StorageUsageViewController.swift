import Foundation
import UIKit
import MixinServices

final class StorageUsageViewController: UIViewController {
    
    @IBOutlet weak var activityIndicatorView: ActivityIndicatorView!
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var activityIndicatorHeightConstraint: NSLayoutConstraint!
    
    private var conversations = [ConversationStorageUsage]()
    
    class func instance() -> UIViewController {
        let vc = R.storyboard.setting.storage_usage()!
        let container = ContainerViewController.instance(viewController: vc, title: Localized.SETTING_STORAGE_USAGE)
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        fetchConversations()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(fetchConversations),
                                               name: MixinServices.storageUsageDidChangeNotification,
                                               object: nil)
    }
    
    @objc private func fetchConversations() {
        let startTime = Date()
        DispatchQueue.global().async { [weak self] in
            let conversations = ConversationDAO.shared.storageUsageConversations()
            DispatchQueue.main.async {
                let time = Date().timeIntervalSince(startTime)
                if time < 1.5 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + (1.5 - time), execute: {
                        self?.reload(conversations: conversations)
                    })
                } else {
                    self?.reload(conversations: conversations)
                }
            }
        }
    }
    
    private func reload(conversations: [ConversationStorageUsage]) {
        self.conversations = conversations
        tableView.reloadData()
        tableView.layoutIfNeeded()
        activityIndicatorHeightConstraint.constant = 0
        UIView.animate(withDuration: 0.3, animations: {
            self.view.layoutIfNeeded()
        }) { (_) in
            self.activityIndicatorView.stopAnimating()
        }
    }
    
}

extension StorageUsageViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.storage_usage, for: indexPath)!
        let conversation = conversations[indexPath.row]
        if conversation.category == ConversationCategory.CONTACT.rawValue {
            cell.avatarImageView.setImage(with: conversation.ownerAvatarUrl ?? "",
                                          userId: conversation.ownerId ?? "",
                                          name: conversation.ownerFullName ?? "")
        } else {
            cell.avatarImageView.setGroupImage(with: conversation.iconUrl ?? "")
        }
        cell.nameLabel.text = conversation.getConversationName()
        cell.sizeLabel.text = VideoMessageViewModel.byteCountFormatter.string(fromByteCount: conversation.mediaSize ?? 0)
        return cell
    }
    
}

extension StorageUsageViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        navigationController?.pushViewController(ClearStorageViewController.instance(conversation: conversations[indexPath.row]), animated: true)
    }
    
}
