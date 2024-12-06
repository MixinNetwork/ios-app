import UIKit
import MixinServices

class ConversationSettingViewController: SettingsTableViewController {
    
    private let messageSourceSection = SettingsRadioSection(header: R.string.localizable.setting_conversation_tip(), rows: [
        SettingsRow(title: R.string.localizable.everybody(), accessory: .none),
        SettingsRow(title: R.string.localizable.my_contacts(), accessory: .none)
    ])
    private let conversationSourceSection = SettingsRadioSection(header: R.string.localizable.setting_conversation_group_tip(), rows: [
        SettingsRow(title: R.string.localizable.everybody(), accessory: .none),
        SettingsRow(title: R.string.localizable.my_contacts(), accessory: .none)
    ])
    
    private lazy var dataSource = SettingsDataSource(sections: [messageSourceSection, conversationSourceSection])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.conversation()
        if let account = LoginManager.shared.account {
            switch account.receiveMessageSource {
            case ReceiveMessageSource.everybody.rawValue:
                messageSourceSection.setAccessory(.checkmark, forRowAt: 0)
            case ReceiveMessageSource.contacts.rawValue:
                messageSourceSection.setAccessory(.checkmark, forRowAt: 1)
            default:
                break
            }
            switch account.acceptConversationSource {
            case AcceptConversationSource.everybody.rawValue:
                conversationSourceSection.setAccessory(.checkmark, forRowAt: 0)
            case AcceptConversationSource.contacts.rawValue:
                conversationSourceSection.setAccessory(.checkmark, forRowAt: 1)
            default:
                break
            }
        }
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
}

extension ConversationSettingViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            let newSource: ReceiveMessageSource = indexPath.row == 0 ? .everybody : .contacts
            if newSource.rawValue != LoginManager.shared.account?.receiveMessageSource {
                tableView.isUserInteractionEnabled = false
                if newSource == .everybody {
                    setMessageSourceEverybody()
                } else {
                    setMessageSourceContacts()
                }
            }
        } else if indexPath.section == 1 {
            let newSource: AcceptConversationSource = indexPath.row == 0 ? .everybody : .contacts
            if newSource.rawValue != LoginManager.shared.account?.acceptConversationSource {
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
        messageSourceSection.setAccessory(.busy, forRowAt: 0)
        let request = UserPreferenceRequest(receive_message_source: ReceiveMessageSource.everybody.rawValue)
        AccountAPI.preferences(preferenceRequest: request, completion: { [weak self] (result) in
            guard let self = self else {
                return
            }
            self.tableView.isUserInteractionEnabled = true
            switch result {
            case .success(let account):
                self.messageSourceSection.setAccessory(.checkmark, forRowAt: 0)
                LoginManager.shared.setAccount(account)
            case let .failure(error):
                self.messageSourceSection.setAccessory(.checkmark, forRowAt: 1)
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        })
    }
    
    private func setMessageSourceContacts() {
        messageSourceSection.setAccessory(.busy, forRowAt: 1)
        let request = UserPreferenceRequest(receive_message_source: ReceiveMessageSource.contacts.rawValue)
        AccountAPI.preferences(preferenceRequest: request, completion: { [weak self] (result) in
            guard let self = self else {
                return
            }
            self.tableView.isUserInteractionEnabled = true
            switch result {
            case .success(let account):
                self.messageSourceSection.setAccessory(.checkmark, forRowAt: 1)
                LoginManager.shared.setAccount(account)
            case let .failure(error):
                self.messageSourceSection.setAccessory(.checkmark, forRowAt: 0)
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        })
    }
    
    private func setConversationSourceEverybody() {
        conversationSourceSection.setAccessory(.busy, forRowAt: 0)
        let request = UserPreferenceRequest(accept_conversation_source: AcceptConversationSource.everybody.rawValue)
        AccountAPI.preferences(preferenceRequest: request, completion: { [weak self] (result) in
            guard let self = self else {
                return
            }
            self.tableView.isUserInteractionEnabled = true
            switch result {
            case .success(let account):
                self.conversationSourceSection.setAccessory(.checkmark, forRowAt: 0)
                LoginManager.shared.setAccount(account)
            case let .failure(error):
                self.conversationSourceSection.setAccessory(.checkmark, forRowAt: 1)
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        })
    }
    
    private func setConversationSourceContacts() {
        conversationSourceSection.setAccessory(.busy, forRowAt: 1)
        let request = UserPreferenceRequest(accept_conversation_source: AcceptConversationSource.contacts.rawValue)
        AccountAPI.preferences(preferenceRequest: request, completion: { [weak self] (result) in
            guard let self = self else {
                return
            }
            self.tableView.isUserInteractionEnabled = true
            switch result {
            case .success(let account):
                self.conversationSourceSection.setAccessory(.checkmark, forRowAt: 1)
                LoginManager.shared.setAccount(account)
            case let .failure(error):
                self.conversationSourceSection.setAccessory(.checkmark, forRowAt: 0)
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        })
    }
    
}
