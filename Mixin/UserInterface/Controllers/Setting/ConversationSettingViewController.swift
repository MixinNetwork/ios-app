import UIKit

class ConversationSettingViewController: UITableViewController {
    
    @IBOutlet weak var messageSourceEverybodyCell: UITableViewCell!
    @IBOutlet weak var messageSourceEverybodyIndicator: UIActivityIndicatorView!
    @IBOutlet weak var messageSourceEverybodyCheckmarkView: CheckmarkView!
    @IBOutlet weak var messageSourceContactsCell: UITableViewCell!
    @IBOutlet weak var messageSourceContactsIndicator: UIActivityIndicatorView!
    @IBOutlet weak var messageSourceContactsCheckmarkView: CheckmarkView!
    @IBOutlet weak var conversationSourceEverybodyCell: UITableViewCell!
    @IBOutlet weak var conversationSourceEverybodyIndicator: UIActivityIndicatorView!
    @IBOutlet weak var conversationSourceEverybodyCheckmarkView: CheckmarkView!
    @IBOutlet weak var conversationSourceContactsCell: UITableViewCell!
    @IBOutlet weak var conversationSourceContactsIndicator: UIActivityIndicatorView!
    @IBOutlet weak var conversationSourceContactsCheckmarkView: CheckmarkView!
    
    @IBOutlet var cells: [UITableViewCell]!
    @IBOutlet var checkmarkViews: [CheckmarkView]!
    
    private let footerReuseId = "footer"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(SeparatorShadowFooterView.self,
                           forHeaderFooterViewReuseIdentifier: footerReuseId)
        checkmarkViews.forEach {
            $0.status = .selected
            $0.alpha = 0
        }
        cells.forEach {
            $0.selectedBackgroundView = UIView.createSelectedBackgroundView()
        }
        if let account = AccountAPI.shared.account {
            switch account.receive_message_source {
            case ReceiveMessageSource.everybody.rawValue:
                messageSourceEverybodyCheckmarkView.alpha = 1
            case ReceiveMessageSource.contacts.rawValue:
                messageSourceContactsCheckmarkView.alpha = 1
            default:
                break
            }
            switch account.accept_conversation_source {
            case AcceptConversationSource.everybody.rawValue:
                conversationSourceEverybodyCheckmarkView.alpha = 1
            case AcceptConversationSource.contacts.rawValue:
                conversationSourceContactsCheckmarkView.alpha = 1
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
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return tableView.dequeueReusableHeaderFooterView(withIdentifier: footerReuseId)
    }
    
}

extension ConversationSettingViewController {
    
    private func setMessageSourceEverybody() {
        messageSourceContactsCheckmarkView.alpha = 0
        messageSourceEverybodyCheckmarkView.alpha = 0
        messageSourceEverybodyIndicator.startAnimating()
        let userRequest = UserRequest(full_name: nil,
                                      avatar_base64: nil,
                                      notification_token: nil,
                                      receive_message_source: ReceiveMessageSource.everybody.rawValue,
                                      accept_conversation_source: nil)
        AccountAPI.shared.preferences(userRequest: userRequest, completion: { [weak self] (result) in
            self?.messageSourceEverybodyIndicator.stopAnimating()
            self?.tableView.isUserInteractionEnabled = true
            self?.messageSourceEverybodyCheckmarkView.alpha = 1
            switch result {
            case .success:
                self?.messageSourceEverybodyCheckmarkView.alpha = 1
                if let old = AccountAPI.shared.account {
                    let newAccount = Account(withAccount: old, receiveMessageSource: .everybody)
                    AccountAPI.shared.account = newAccount
                }
            case let .failure(error):
                showHud(style: .error, text: error.localizedDescription)
                self?.messageSourceContactsCheckmarkView.alpha = 1
            }
        })
    }
    
    private func setMessageSourceContacts() {
        messageSourceEverybodyCheckmarkView.alpha = 0
        messageSourceContactsCheckmarkView.alpha = 0
        messageSourceContactsIndicator.startAnimating()
        let userRequest = UserRequest(full_name: nil,
                                      avatar_base64: nil,
                                      notification_token: nil,
                                      receive_message_source: ReceiveMessageSource.contacts.rawValue,
                                      accept_conversation_source: nil)
        AccountAPI.shared.preferences(userRequest: userRequest, completion: { [weak self] (result) in
            self?.messageSourceContactsIndicator.stopAnimating()
            self?.messageSourceContactsCheckmarkView.alpha = 1
            self?.tableView.isUserInteractionEnabled = true
            switch result {
            case .success:
                self?.messageSourceContactsCheckmarkView.alpha = 1
                if let old = AccountAPI.shared.account {
                    let newAccount = Account(withAccount: old, receiveMessageSource: .contacts)
                    AccountAPI.shared.account = newAccount
                }
            case let .failure(error):
                showHud(style: .error, text: error.localizedDescription)
                self?.messageSourceEverybodyCheckmarkView.alpha = 1
            }
        })
    }
    
    private func setConversationSourceEverybody() {
        conversationSourceContactsCheckmarkView.alpha = 0
        conversationSourceEverybodyCheckmarkView.alpha = 0
        conversationSourceEverybodyIndicator.startAnimating()
        let userRequest = UserRequest(full_name: nil,
                                      avatar_base64: nil,
                                      notification_token: nil,
                                      receive_message_source: nil,
                                      accept_conversation_source: AcceptConversationSource.everybody.rawValue)
        AccountAPI.shared.preferences(userRequest: userRequest, completion: { [weak self] (result) in
            self?.conversationSourceEverybodyIndicator.stopAnimating()
            self?.conversationSourceEverybodyCheckmarkView.alpha = 1
            self?.tableView.isUserInteractionEnabled = true
            switch result {
            case .success:
                self?.conversationSourceEverybodyCheckmarkView.alpha = 1
                if let old = AccountAPI.shared.account {
                    let newAccount = Account(withAccount: old, acceptConversationSource: .everybody)
                    AccountAPI.shared.account = newAccount
                }
            case let .failure(error):
                showHud(style: .error, text: error.localizedDescription)
                self?.conversationSourceContactsCheckmarkView.alpha = 1
            }
        })
    }
    
    private func setConversationSourceContacts() {
        conversationSourceContactsIndicator.startAnimating()
        conversationSourceEverybodyCheckmarkView.alpha = 0
        conversationSourceContactsCheckmarkView.alpha = 0
        let userRequest = UserRequest(full_name: nil,
                                      avatar_base64: nil,
                                      notification_token: nil,
                                      receive_message_source: nil,
                                      accept_conversation_source: AcceptConversationSource.contacts.rawValue)
        AccountAPI.shared.preferences(userRequest: userRequest, completion: { [weak self] (result) in
            self?.conversationSourceContactsIndicator.stopAnimating()
            self?.tableView.isUserInteractionEnabled = true
            self?.conversationSourceContactsCheckmarkView.alpha = 1
            switch result {
            case .success:
                self?.conversationSourceContactsCheckmarkView.alpha = 1
                if let old = AccountAPI.shared.account {
                    let newAccount = Account(withAccount: old, acceptConversationSource: .contacts)
                    AccountAPI.shared.account = newAccount
                }
            case let .failure(error):
                showHud(style: .error, text: error.localizedDescription)
                self?.conversationSourceEverybodyCheckmarkView.alpha = 1
            }
        })
    }
    
}
