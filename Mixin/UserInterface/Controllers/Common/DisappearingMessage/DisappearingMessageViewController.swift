import UIKit
import MixinServices

final class DisappearingMessageViewController: SettingsTableViewController {
    
    private let rows = Option.allCases.map { option in
        SettingsRow(title: option.title, accessory: .none)
    }
    
    private var currentExpireIn: Int64 = 0
    private var conversationId = ""
    
    private lazy var section = SettingsRadioSection(rows: rows)
    private lazy var dataSource = SettingsDataSource(sections: [section])
    
    class func instance(conversationId: String, expireIn: Int64) -> UIViewController {
        let vc = DisappearingMessageViewController()
        vc.conversationId = conversationId
        vc.currentExpireIn = expireIn
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.disappearing_message_title())
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableHeaderView = R.nib.disappearingMessageTableHeaderView(owner: nil)
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
        setAccessory(.checkmark, forRowWith: currentExpireIn)
    }
    
}

extension DisappearingMessageViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let option = Option.allCases[indexPath.row]
        if let expireIn = option.expireIn {
            update(expireIn: expireIn)
        } else {
            let window = DisappearingMessageTimePickerWindow.instance()
            window.render(expireIn: currentExpireIn)
            window.onPick = update(expireIn:)
            window.presentPopupControllerAnimated()
        }
    }
    
}

extension DisappearingMessageViewController {
    
    private enum Option: CaseIterable {
        
        case off
        case thirtySeconds
        case tenMinutes
        case twoHours
        case oneDay
        case oneWeek
        case custom
        
        init(expireIn: Int64) {
            switch TimeInterval(expireIn) {
            case 0:
                self = .off
            case 30:
                self = .thirtySeconds
            case 10 * .minute:
                self = .tenMinutes
            case 2 * .hour:
                self = .twoHours
            case .day:
                self = .oneDay
            case .week:
                self = .oneWeek
            default:
                self = .custom
            }
        }
        
        var expireIn: Int64? {
            switch self {
            case .off:
                return 0
            case .thirtySeconds:
                return 30
            case .tenMinutes:
                return Int64(10 * TimeInterval.minute)
            case .twoHours:
                return Int64(2 * TimeInterval.hour)
            case .oneDay:
                return Int64(TimeInterval.day)
            case .oneWeek:
                return Int64(TimeInterval.week)
            case .custom:
                return nil
            }
        }
        
        var title: String {
            switch self {
            case .off:
                return R.string.localizable.setting_backup_off()
            case .thirtySeconds:
                return R.string.localizable.disappearing_message_30seconds()
            case .tenMinutes:
                return R.string.localizable.disappearing_message_10minutes()
            case .twoHours:
                return R.string.localizable.disappearing_message_2hours()
            case .oneDay:
                return R.string.localizable.disappearing_message_1day()
            case .oneWeek:
                return R.string.localizable.disappearing_message_1week()
            case .custom:
                return R.string.localizable.disappearing_message_custom_time()
            }
        }
        
    }
    
    private func setAccessory(_ accessory: SettingsRow.Accessory, forRowWith expireIn: Int64) {
        let option = Option(expireIn: expireIn)
        guard let index = Option.allCases.firstIndex(of: option) else {
            assertionFailure("No way an option not included in allCases")
            return
        }
        switch option {
        case .custom:
            rows[index].subtitle = DisappearingMessageDurationFormatter.string(from: expireIn)
        default:
            if let index = Option.allCases.firstIndex(of: .custom) {
                rows[index].subtitle = nil
            }
        }
        section.setAccessory(accessory, forRowAt: index)
    }
    
    private func update(expireIn: Int64) {
        guard expireIn != currentExpireIn else {
            return
        }
        tableView.isUserInteractionEnabled = false
        setAccessory(.busy, forRowWith: expireIn)
        let conversationId = self.conversationId
        ConversationAPI.updateExpireIn(conversationId: conversationId, expireIn: expireIn) { [weak self] result in
            switch result {
            case .success:
                ConversationDAO.shared.updateExpireIn(expireIn: expireIn, conversationId: conversationId)
                self?.currentExpireIn = expireIn
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
            if let self = self {
                self.setAccessory(.checkmark, forRowWith: self.currentExpireIn)
                self.tableView.isUserInteractionEnabled = true
            }
        }
    }
    
}
