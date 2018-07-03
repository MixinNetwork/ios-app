import UIKit

class ConversationSettingViewController: UITableViewController {

    @IBOutlet weak var MessageSourceEverybodyCell: UITableViewCell!
    @IBOutlet weak var MessageSourceEverybodyIndicator: UIActivityIndicatorView!
    @IBOutlet weak var MessageSourceContactsCell: UITableViewCell!
    @IBOutlet weak var MessageSourceContactsIndicator: UIActivityIndicatorView!
    @IBOutlet weak var ConversationSourceEverybodyCell: UITableViewCell!
    @IBOutlet weak var ConversationSourceEverybodyIndicator: UIActivityIndicatorView!
    @IBOutlet weak var ConversationSourceContactsCell: UITableViewCell!
    @IBOutlet weak var ConversationSourceContactsIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let account = AccountAPI.shared.account {
            switch account.receive_message_source {
            case ReceiveMessageSource.everybody.rawValue:
                MessageSourceEverybodyCell.accessoryType = .checkmark
            case ReceiveMessageSource.contacts.rawValue:
                MessageSourceContactsCell.accessoryType = .checkmark
            default:
                break
            }
            switch account.accept_conversation_source {
            case AcceptConversationSource.everybody.rawValue:
                ConversationSourceEverybodyCell.accessoryType = .checkmark
            case AcceptConversationSource.contacts.rawValue:
                ConversationSourceContactsCell.accessoryType = .checkmark
            default:
                break
            }
        }
    }
    
    class func instance() -> UIViewController {
        return ContainerViewController.instance(viewController: Storyboard.setting.instantiateViewController(withIdentifier: "conversation"), title: Localized.SETTING_CONVERSATION)
    }

}

extension ConversationSettingViewController {

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return Localized.SETTING_HEADER_MESSAGE_SOURCE
        case 1:
            return Localized.SETTING_HEADER_CONVERSATION_SOURCE
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            let newSource: ReceiveMessageSource = indexPath.row == 0 ? .everybody : .contacts
            if newSource.rawValue != AccountAPI.shared.account?.receive_message_source {
                tableView.isUserInteractionEnabled = false
                if newSource == .everybody {
                    setMessageSourceEverybody()
                } else {
                    setMessageSourceContacts()
                }
            }
        } else if indexPath.section == 1 {
            let newSource: AcceptConversationSource = indexPath.row == 0 ? .everybody : .contacts
            if newSource.rawValue != AccountAPI.shared.account?.accept_conversation_source {
                tableView.isUserInteractionEnabled = false
                if newSource == .everybody {
                    setConversationSourceEverybody()
                } else {
                    setConversationSourceContacts()
                }
            }
        }
    }
    
}

extension ConversationSettingViewController {
    
    private func setMessageSourceEverybody() {
        MessageSourceContactsCell.accessoryType = .none
        MessageSourceEverybodyIndicator.startAnimating()
        let userRequest = UserRequest(full_name: nil,
                                      avatar_base64: nil,
                                      notification_token: nil,
                                      receive_message_source: ReceiveMessageSource.everybody.rawValue,
                                      accept_conversation_source: nil)
        AccountAPI.shared.preferences(userRequest: userRequest, completion: { [weak self] (result) in
            self?.MessageSourceEverybodyIndicator.stopAnimating()
            self?.tableView.isUserInteractionEnabled = true
            switch result {
            case .success:
                self?.MessageSourceEverybodyCell.accessoryType = .checkmark
                if let old = AccountAPI.shared.account {
                    let newAccount = Account(withAccount: old, receiveMessageSource: .everybody)
                    AccountAPI.shared.account = newAccount
                }
            case .failure:
                self?.MessageSourceContactsCell.accessoryType = .checkmark
            }
        })
    }
    
    private func setMessageSourceContacts() {
        MessageSourceContactsIndicator.startAnimating()
        MessageSourceEverybodyCell.accessoryType = .none
        let userRequest = UserRequest(full_name: nil,
                                      avatar_base64: nil,
                                      notification_token: nil,
                                      receive_message_source: ReceiveMessageSource.contacts.rawValue,
                                      accept_conversation_source: nil)
        AccountAPI.shared.preferences(userRequest: userRequest, completion: { [weak self] (result) in
            self?.MessageSourceContactsIndicator.stopAnimating()
            self?.tableView.isUserInteractionEnabled = true
            switch result {
            case .success:
                self?.MessageSourceContactsCell.accessoryType = .checkmark
                if let old = AccountAPI.shared.account {
                    let newAccount = Account(withAccount: old, receiveMessageSource: .contacts)
                    AccountAPI.shared.account = newAccount
                }
            case .failure:
                self?.MessageSourceEverybodyCell.accessoryType = .checkmark
            }
        })
    }
    
    private func setConversationSourceEverybody() {
        ConversationSourceContactsCell.accessoryType = .none
        ConversationSourceEverybodyIndicator.startAnimating()
        let userRequest = UserRequest(full_name: nil,
                                      avatar_base64: nil,
                                      notification_token: nil,
                                      receive_message_source: nil,
                                      accept_conversation_source: AcceptConversationSource.everybody.rawValue)
        AccountAPI.shared.preferences(userRequest: userRequest, completion: { [weak self] (result) in
            self?.ConversationSourceEverybodyIndicator.stopAnimating()
            self?.tableView.isUserInteractionEnabled = true
            switch result {
            case .success:
                self?.ConversationSourceEverybodyCell.accessoryType = .checkmark
                if let old = AccountAPI.shared.account {
                    let newAccount = Account(withAccount: old, acceptConversationSource: .everybody)
                    AccountAPI.shared.account = newAccount
                }
            case .failure:
                self?.ConversationSourceContactsCell.accessoryType = .checkmark
            }
        })
    }
    
    private func setConversationSourceContacts() {
        ConversationSourceContactsIndicator.startAnimating()
        ConversationSourceEverybodyCell.accessoryType = .none
        let userRequest = UserRequest(full_name: nil,
                                      avatar_base64: nil,
                                      notification_token: nil,
                                      receive_message_source: nil,
                                      accept_conversation_source: AcceptConversationSource.contacts.rawValue)
        AccountAPI.shared.preferences(userRequest: userRequest, completion: { [weak self] (result) in
            self?.ConversationSourceContactsIndicator.stopAnimating()
            self?.tableView.isUserInteractionEnabled = true
            switch result {
            case .success:
                self?.ConversationSourceContactsCell.accessoryType = .checkmark
                if let old = AccountAPI.shared.account {
                    let newAccount = Account(withAccount: old, acceptConversationSource: .contacts)
                    AccountAPI.shared.account = newAccount
                }
            case .failure:
                self?.ConversationSourceEverybodyCell.accessoryType = .checkmark
            }
        })
    }
    
}
