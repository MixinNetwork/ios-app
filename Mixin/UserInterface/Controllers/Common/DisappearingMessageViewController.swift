import UIKit
import MixinServices

final class DisappearingMessageViewController: SettingsTableViewController {
    
    private enum Time: Int {
        case off = 0
        case halfSecond
        case tenMinutes
        case twoHours
        case oneDay
        case oneWeek
        case custom
        
        init(interval: TimeInterval) {
            switch interval {
            case 0:
                self = .off
            case .oneMinute / 2:
                self = .halfSecond
            case .oneMinute * 10:
                self = .tenMinutes
            case .oneHour * 2:
                self = .twoHours
            case .oneDay:
                self = .oneDay
            case .oneWeek:
                self = .oneWeek
            default:
                self = .custom
            }
        }
        
        init(index: Int) {
            switch index {
            case 0:
                self = .off
            case 1:
                self = .halfSecond
            case 2:
                self = .tenMinutes
            case 3:
                self = .twoHours
            case 4:
                self = .oneDay
            case 5:
                self = .oneWeek
            default:
                self = .custom
            }
        }
        
        var index: Int {
            rawValue
        }
        
        var title: String {
            switch self {
            case .off:
                return R.string.localizable.setting_backup_off()
            case .halfSecond:
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
        
        var interval: TimeInterval {
            switch self {
            case .off:
                return 0
            case .halfSecond:
                return 30
            case .tenMinutes:
                return 10 * .oneMinute
            case .twoHours:
                return 2 * .oneHour
            case .oneDay:
                return .oneDay
            case .oneWeek:
                return .oneWeek
            case .custom:
                return 0
            }
        }
    }
    
    private var previousTime: Time = .off
    private var disappearingTimeInterval: TimeInterval = 0
    private var disappearingTimeTitle: String = ""
    private var conversationId = ""
    private lazy var rows = [
        SettingsRow(title: Time.off.title, accessory: .none),
        SettingsRow(title: Time.halfSecond.title, accessory: .none),
        SettingsRow(title: Time.tenMinutes.title, accessory: .none),
        SettingsRow(title: Time.twoHours.title, accessory: .none),
        SettingsRow(title: Time.oneDay.title, accessory: .none),
        SettingsRow(title: Time.oneWeek.title, accessory: .none),
        SettingsRow(title: Time.custom.title, accessory: .none)
    ]
    private lazy var section = SettingsRadioSection(rows: rows)
    private lazy var dataSource = SettingsDataSource(sections: [section])
    
    class func instance(conversationId: String) -> UIViewController {
        let vc = DisappearingMessageViewController()
        vc.conversationId = conversationId
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.disappearing_message_title())
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableHeaderView = R.nib.disappearingMessageTableHeaderView(owner: nil)
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
        updateSelectedRow()
    }
}

extension DisappearingMessageViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        tableView.isUserInteractionEnabled = false
        let time = Time(index: indexPath.row)
        if time == .custom {
            section.setAccessory(.none, forRowAt: time.index)
            let window = DisappearingMessageTimePickerWindow.instance()
            window.render(timeInterval: disappearingTimeInterval)
            window.onClose = {
                self.tableView.isUserInteractionEnabled = true
                self.section.setAccessory(.checkmark, forRowAt: self.previousTime.index)
            }
            window.onChange = { (timeInterval, timeTitle) in
                self.disappearingTimeTitle = timeTitle
                self.disappearingTimeInterval = timeInterval
                self.updateDisappearingMessageTime(time: time)
            }
            window.presentPopupControllerAnimated()
        } else {
            rows[Time.custom.index].subtitle = nil
            disappearingTimeInterval = time.interval
            section.setAccessory(.busy, forRowAt: time.index)
            if time == .off {
                closeDisappearingMessage(time: time)
            } else {
                updateDisappearingMessageTime(time: time)
            }
        }
    }
    
}

extension DisappearingMessageViewController {
    
    private func updateDisappearingMessageTime(time: Time) {
        if previousTime == .off {
            ConversationAPI.openDisappearingMessage(conversationId: conversationId) { [weak self] result in
                guard let self = self else {
                    return
                }
                self.tableView.isUserInteractionEnabled = true
                switch result {
                case .success:
                    self.section.setAccessory(.checkmark, forRowAt: time.index)
                    // send message
                    self.previousTime = time
                case let .failure(error):
                    self.section.setAccessory(.checkmark, forRowAt: self.previousTime.index)
                    showAutoHiddenHud(style: .error, text: error.localizedDescription)
                }
            }
        } else {
            // send message, queue for mock
            self.section.setAccessory(.busy, forRowAt: time.index)
            self.rows[Time.custom.index].subtitle = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.tableView.isUserInteractionEnabled = true
                if time == .custom {
                    self.rows[Time.custom.index].subtitle = self.disappearingTimeTitle
                }
                self.section.setAccessory(.checkmark, forRowAt: time.index)
                self.previousTime = time
            }
        }
    }
    
    private func closeDisappearingMessage(time: Time) {
        ConversationAPI.closeDisappearingMessage(conversationId: conversationId) { [weak self] result in
            guard let self = self else {
                return
            }
            self.tableView.isUserInteractionEnabled = true
            switch result {
            case .success:
                self.section.setAccessory(.checkmark, forRowAt: time.index)
                // send message
                self.previousTime = time
            case let .failure(error):
                self.section.setAccessory(.checkmark, forRowAt: self.previousTime.index)
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
    }
    
    private func updateSelectedRow() {
        // fetch from db
        let timeInterval: TimeInterval = 30
        
        let time = Time(interval: timeInterval)
        if time == .custom {
            let unit: String
            let duration: Int
            if timeInterval < .oneMinute {
                unit = R.string.localizable.disappearing_message_seconds_unit()
                duration = Int(timeInterval) - 1
            } else if timeInterval < .oneHour {
                unit = R.string.localizable.disappearing_message_minutes_unit()
                duration = Int(timeInterval / .oneMinute) - 1
            } else if timeInterval < .oneDay {
                unit = R.string.localizable.disappearing_message_hours_unit()
                duration = Int(timeInterval / .oneHour) - 1
            } else if timeInterval < .oneWeek {
                unit = R.string.localizable.disappearing_message_days_unit()
                duration = Int(timeInterval / .oneDay) - 1
            } else {
                unit = R.string.localizable.disappearing_message_weeks_unit()
                duration = Int(timeInterval / .oneWeek) - 1
            }
            rows[Time.custom.index].subtitle = "\(duration) \(unit)"
        } else {
            section.setAccessory(.checkmark, forRowAt: time.index)
        }
        previousTime = time
    }
    
}
