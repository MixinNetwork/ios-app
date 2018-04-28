import UIKit

class ConversationSettingViewController: UITableViewController {

    @IBOutlet weak var everybodyCell: UITableViewCell!
    @IBOutlet weak var everybodyIndicator: UIActivityIndicatorView!
    @IBOutlet weak var contactsCell: UITableViewCell!
    @IBOutlet weak var contactsIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let account = AccountAPI.shared.account {
            switch account.receive_message_source {
            case ReceiveMessageSource.everybody.rawValue:
                everybodyCell.accessoryType = .checkmark
            case ReceiveMessageSource.contacts.rawValue:
                contactsCell.accessoryType = .checkmark
            default:
                contactsCell.accessoryType = .none
            }
        }
    }
    
    class func instance() -> UIViewController {
        return ContainerViewController.instance(viewController: Storyboard.setting.instantiateViewController(withIdentifier: "conversation"), title: Localized.SETTING_CONVERSATION)
    }

    private func indexPath(forSource source: ReceiveMessageSource) -> IndexPath {
        if source == .everybody {
            return IndexPath(row: 0, section: 0)
        } else {
            return IndexPath(row: 1, section: 0)
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return Localized.SETTING_CONVERSATION_SUMMARY
    }
}

extension ConversationSettingViewController {

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let newSource: ReceiveMessageSource = indexPath.row == 0 ? .everybody : .contacts
        guard newSource.rawValue != AccountAPI.shared.account?.receive_message_source else {
            return
        }
        tableView.isUserInteractionEnabled = false
        if newSource == .everybody {
            contactsCell.accessoryType = .none
            everybodyIndicator.startAnimating()
            let userRequest = UserRequest(full_name: nil,
                                          avatar_base64: nil,
                                          notification_token: nil,
                                          receive_message_source: ReceiveMessageSource.everybody.rawValue)
            AccountAPI.shared.preferences(userRequest: userRequest, completion: { [weak self] (result) in
                self?.everybodyIndicator.stopAnimating()
                self?.tableView.isUserInteractionEnabled = true
                switch result {
                case .success:
                    self?.everybodyCell.accessoryType = .checkmark
                    if let old = AccountAPI.shared.account {
                        let newAccount = Account(withAccount: old, receiveMessageSource: .everybody)
                        AccountAPI.shared.account = newAccount
                    }
                    self?.navigationController?.popViewController(animated: true)
                case .failure:
                    self?.contactsCell.accessoryType = .checkmark
                }
            })
        } else {
            contactsIndicator.startAnimating()
            everybodyCell.accessoryType = .none
            let userRequest = UserRequest(full_name: nil,
                                          avatar_base64: nil,
                                          notification_token: nil,
                                          receive_message_source: ReceiveMessageSource.contacts.rawValue)
            AccountAPI.shared.preferences(userRequest: userRequest, completion: { [weak self] (result) in
                self?.contactsIndicator.stopAnimating()
                self?.tableView.isUserInteractionEnabled = true
                switch result {
                case .success:
                    self?.contactsCell.accessoryType = .checkmark
                    if let old = AccountAPI.shared.account {
                        let newAccount = Account(withAccount: old, receiveMessageSource: .contacts)
                        AccountAPI.shared.account = newAccount
                    }
                    self?.navigationController?.popViewController(animated: true)
                case .failure:
                    self?.everybodyCell.accessoryType = .checkmark
                }
            })
        }
    }
    
}

