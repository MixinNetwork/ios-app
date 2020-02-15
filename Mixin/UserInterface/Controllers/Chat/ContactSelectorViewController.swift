import UIKit
import MixinServices

class ContactSelectorViewController: UserItemPeerViewController<CheckmarkPeerCell>, MixinNavigationAnimating {
    
    private weak var conversationInputViewController: ConversationInputViewController?
    
    private var selections = [String]() // Element is user id
    
    class func instance(conversationInputViewController: ConversationInputViewController) -> UIViewController {
        let vc = ContactSelectorViewController()
        vc.conversationInputViewController = conversationInputViewController
        return ContainerViewController.instance(viewController: vc, title: Localized.PROFILE_SHARE_CARD)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.allowsMultipleSelection = true
    }
    
    override func reloadTableViewSelections() {
        super.reloadTableViewSelections()
        var rows = [Int]()
        if isSearching {
            for (row, result) in searchResults.enumerated() where selections.contains(result.user.userId) {
                rows.append(row)
            }
        } else {
            for (row, user) in models.enumerated() where selections.contains(user.userId) {
                rows.append(row)
            }
        }
        for row in rows {
            let indexPath = IndexPath(row: row, section: 0)
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let userId = user(at: indexPath).userId
        selections.append(userId)
        container?.rightButton.isEnabled = true
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let userId = user(at: indexPath).userId
        if let idx = selections.firstIndex(of: userId) {
            selections.remove(at: idx)
        }
        if tableView.indexPathForSelectedRow == nil {
            container?.rightButton.isEnabled = false
        }
    }
    
}

extension ContactSelectorViewController: ContainerViewControllerDelegate {
    
    func barRightButtonTappedAction() {
        conversationInputViewController?.sendContact(userIds: selections) {
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    func textBarRightButton() -> String? {
        return R.string.localizable.action_send()
    }
    
}
