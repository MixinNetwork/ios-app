import UIKit
import MixinServices

class ConversationSettingViewController: UITableViewController {
    
    @IBOutlet weak var messageSourceEverybodyCell: ModernSelectedBackgroundCell!
    @IBOutlet weak var messageSourceEverybodyIndicator: ActivityIndicatorView!
    @IBOutlet weak var messageSourceEverybodyCheckmarkView: CheckmarkView!
    @IBOutlet weak var messageSourceContactsCell: ModernSelectedBackgroundCell!
    @IBOutlet weak var messageSourceContactsIndicator: ActivityIndicatorView!
    @IBOutlet weak var messageSourceContactsCheckmarkView: CheckmarkView!
    @IBOutlet weak var conversationSourceEverybodyCell: ModernSelectedBackgroundCell!
    @IBOutlet weak var conversationSourceEverybodyIndicator: ActivityIndicatorView!
    @IBOutlet weak var conversationSourceEverybodyCheckmarkView: CheckmarkView!
    @IBOutlet weak var conversationSourceContactsCell: ModernSelectedBackgroundCell!
    @IBOutlet weak var conversationSourceContactsIndicator: ActivityIndicatorView!
    @IBOutlet weak var conversationSourceContactsCheckmarkView: CheckmarkView!
    
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
        if let account = LoginManager.shared.account {
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
        return ContainerViewController.instance(viewController: R.storyboard.setting.conversation()!, title: Localized.SETTING_CONVERSATION)
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
            if newSource.rawValue != LoginManager.shared.account?.receive_message_source {
                tableView.isUserInteractionEnabled = false
                if newSource == .everybody {
                    setMessageSourceEverybody()
                } else {
                    setMessageSourceContacts()
                }
            }
        } else if indexPath.section == 1 {
            let newSource: AcceptConversationSource = indexPath.row == 0 ? .everybody : .contacts
            if newSource.rawValue != LoginManager.shared.account?.accept_conversation_source {
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
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: footerReuseId) as! SeparatorShadowFooterView
        view.shadowView.hasLowerShadow = section != numberOfSections(in: tableView) - 1
        return view
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == 0 {
            return 10
        } else {
            return 15 // Avoid shadow from being clipped
        }
    }
    
}

extension ConversationSettingViewController {
    
    private func setMessageSourceEverybody() {
        messageSourceContactsCheckmarkView.alpha = 0
        messageSourceEverybodyCheckmarkView.alpha = 0
        messageSourceEverybodyIndicator.startAnimating()
        AccountAPI.shared.preferences(preferenceRequest: UserPreferenceRequest(receive_message_source: ReceiveMessageSource.everybody.rawValue), completion: { [weak self] (result) in
            self?.messageSourceEverybodyIndicator.stopAnimating()
            self?.tableView.isUserInteractionEnabled = true
            self?.messageSourceEverybodyCheckmarkView.alpha = 1
            switch result {
            case .success(let account):
                self?.messageSourceEverybodyCheckmarkView.alpha = 1
                LoginManager.shared.setAccount(account)
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
                self?.messageSourceContactsCheckmarkView.alpha = 1
            }
        })
    }
    
    private func setMessageSourceContacts() {
        messageSourceEverybodyCheckmarkView.alpha = 0
        messageSourceContactsCheckmarkView.alpha = 0
        messageSourceContactsIndicator.startAnimating()
        AccountAPI.shared.preferences(preferenceRequest: UserPreferenceRequest(receive_message_source: ReceiveMessageSource.contacts.rawValue), completion: { [weak self] (result) in
            self?.messageSourceContactsIndicator.stopAnimating()
            self?.messageSourceContactsCheckmarkView.alpha = 1
            self?.tableView.isUserInteractionEnabled = true
            switch result {
            case .success(let account):
                self?.messageSourceContactsCheckmarkView.alpha = 1
                LoginManager.shared.setAccount(account)
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
                self?.messageSourceEverybodyCheckmarkView.alpha = 1
            }
        })
    }
    
    private func setConversationSourceEverybody() {
        conversationSourceContactsCheckmarkView.alpha = 0
        conversationSourceEverybodyCheckmarkView.alpha = 0
        conversationSourceEverybodyIndicator.startAnimating()
        AccountAPI.shared.preferences(preferenceRequest: UserPreferenceRequest(accept_conversation_source: AcceptConversationSource.everybody.rawValue), completion: { [weak self] (result) in
            self?.conversationSourceEverybodyIndicator.stopAnimating()
            self?.conversationSourceEverybodyCheckmarkView.alpha = 1
            self?.tableView.isUserInteractionEnabled = true
            switch result {
            case .success(let account):
                self?.conversationSourceEverybodyCheckmarkView.alpha = 1
                LoginManager.shared.setAccount(account)
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
                self?.conversationSourceContactsCheckmarkView.alpha = 1
            }
        })
    }
    
    private func setConversationSourceContacts() {
        conversationSourceContactsIndicator.startAnimating()
        conversationSourceEverybodyCheckmarkView.alpha = 0
        conversationSourceContactsCheckmarkView.alpha = 0
        AccountAPI.shared.preferences(preferenceRequest: UserPreferenceRequest(accept_conversation_source: AcceptConversationSource.contacts.rawValue), completion: { [weak self] (result) in
            self?.conversationSourceContactsIndicator.stopAnimating()
            self?.tableView.isUserInteractionEnabled = true
            self?.conversationSourceContactsCheckmarkView.alpha = 1
            switch result {
            case .success(let account):
                self?.conversationSourceContactsCheckmarkView.alpha = 1
                LoginManager.shared.setAccount(account)
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
                self?.conversationSourceEverybodyCheckmarkView.alpha = 1
            }
        })
    }
    
}
