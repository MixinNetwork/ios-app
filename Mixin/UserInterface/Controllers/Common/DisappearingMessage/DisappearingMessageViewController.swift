import UIKit
import MixinServices

final class DisappearingMessageViewController: SettingsTableViewController {
    
    private var previousDuration: DisappearingMessageDuration = .off
    private var expireIn: UInt32 = 0
    private var expireInTitle: String?
    private var conversationId = ""
    private lazy var rows = [
        SettingsRow(title: DisappearingMessageDuration.off.title, accessory: .none),
        SettingsRow(title: DisappearingMessageDuration.thirtySeconds.title, accessory: .none),
        SettingsRow(title: DisappearingMessageDuration.tenMinutes.title, accessory: .none),
        SettingsRow(title: DisappearingMessageDuration.twoHours.title, accessory: .none),
        SettingsRow(title: DisappearingMessageDuration.oneDay.title, accessory: .none),
        SettingsRow(title: DisappearingMessageDuration.oneWeek.title, accessory: .none),
        SettingsRow(title: DisappearingMessageDuration.custom(expireIn: 0).title, accessory: .none)
    ]
    private lazy var section = SettingsRadioSection(rows: rows)
    private lazy var dataSource = SettingsDataSource(sections: [section])
    
    class func instance(conversationId: String, expireIn: UInt32) -> UIViewController {
        let vc = DisappearingMessageViewController()
        vc.conversationId = conversationId
        vc.expireIn = expireIn
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.disappearing_message_title())
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableHeaderView = R.nib.disappearingMessageTableHeaderView(owner: nil)
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
        let duration = DisappearingMessageDuration(expireIn: expireIn)
        if case .custom = duration {
            expireInTitle = duration.expireInTitle
            rows[duration.index].subtitle = expireInTitle
        }
        section.setAccessory(.checkmark, forRowAt: duration.index)
        previousDuration = duration
    }
}

extension DisappearingMessageViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let duration = DisappearingMessageDuration(index: indexPath.row)
        if case .custom = duration {
            section.setAccessory(.none, forRowAt: duration.index)
            let window = DisappearingMessageTimePickerWindow.instance()
            window.render(expireIn: expireIn)
            window.onClose = { [weak self] in
                guard let self = self else {
                    return
                }
                self.section.setAccessory(.checkmark, forRowAt: self.previousDuration.index)
            }
            window.onChange = { [weak self] (expireIn, expireInTitle) in
                guard let self = self else {
                    return
                }
                self.updateDisappearingMessageDuration(duration: duration, expireIn: expireIn, expireInTitle: expireInTitle)
            }
            window.presentPopupControllerAnimated()
        } else if duration != previousDuration {
            if case .off = duration {
                closeDisappearingMessage(duration: duration)
            } else {
                updateDisappearingMessageDuration(duration: duration, expireIn: UInt32(duration.interval))
            }
        }
    }
    
}

extension DisappearingMessageViewController {
    
    private func updateDisappearingMessageDuration(duration: DisappearingMessageDuration, expireIn: UInt32, expireInTitle: String? = nil) {
        tableView.isUserInteractionEnabled = false
        if case .custom = previousDuration {
            rows[previousDuration.index].subtitle = nil
        }
        section.setAccessory(.busy, forRowAt: duration.index)
        ConversationAPI.openDisappearingMessage(conversationId: conversationId, expireIn: expireIn) { [weak self] result in
            guard let self = self else {
                return
            }
            switch result {
            case .success:
                ConversationDAO.shared.updateExpireIn(expireIn: expireIn, conversationId: self.conversationId)
                self.section.setAccessory(.checkmark, forRowAt: duration.index)
                if case .custom = duration {
                    self.rows[duration.index].subtitle = expireInTitle
                }
                self.expireIn = expireIn
                self.expireInTitle = expireInTitle
                self.previousDuration = duration
            case let .failure(error):
                self.section.setAccessory(.checkmark, forRowAt: self.previousDuration.index)
                if case .custom = self.previousDuration {
                    self.rows[self.previousDuration.index].subtitle = self.expireInTitle
                }
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
            self.tableView.isUserInteractionEnabled = true
        }
    }
    
    private func closeDisappearingMessage(duration: DisappearingMessageDuration) {
        tableView.isUserInteractionEnabled = false
        section.setAccessory(.busy, forRowAt: duration.index)
        rows[duration.index].subtitle = nil
        ConversationAPI.closeDisappearingMessage(conversationId: conversationId) { [weak self] result in
            guard let self = self else {
                return
            }
            switch result {
            case .success:
                ConversationDAO.shared.updateExpireIn(expireIn: 0, conversationId: self.conversationId)
                self.section.setAccessory(.checkmark, forRowAt: duration.index)
                self.expireIn = 0
                self.expireInTitle = nil
                self.previousDuration = duration
            case let .failure(error):
                self.section.setAccessory(.checkmark, forRowAt: self.previousDuration.index)
                if case .custom = self.previousDuration {
                    self.rows[self.previousDuration.index].subtitle = self.expireInTitle
                }
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
            self.tableView.isUserInteractionEnabled = true
        }
    }
    
}
