import UIKit
import MixinServices

class NotificationSettingViewController: SettingsTableViewController {
    
    private lazy var showNotificationRow = SettingsRow(title: R.string.localizable.setting_notification_show(),
                                                       accessory: .switch(isOn: showNotifications))
    private lazy var showMessagePreviewRow = SettingsRow(title: R.string.localizable.setting_notification_message_preview(),
                                                         accessory: .switch(isOn: showMessagePreview, isEnabled: showNotifications))
    private lazy var showGroupNotificationRow = SettingsRow(title: R.string.localizable.setting_notification_show(),
                                                            accessory: .switch(isOn: showGroupNotifications))
    private lazy var showGroupMessagePreviewRow = SettingsRow(title: R.string.localizable.setting_notification_message_preview(),
                                                              accessory: .switch(isOn: showGroupMessagePreview, isEnabled: showGroupNotifications))
    private lazy var countUnreadMessageRow = SettingsRow(title: R.string.localizable.setting_notification_count_unread_messages(),
                                                         accessory: .switch(isOn: countUnreadMessage))
    
    private lazy var dataSource = SettingsDataSource(sections: [
        SettingsSection(header: R.string.localizable.setting_notification_message(), rows: [
            showNotificationRow,
            showMessagePreviewRow
        ]),
        SettingsSection(header: R.string.localizable.setting_notification_group(), rows: [
            showGroupNotificationRow,
            showGroupMessagePreviewRow
        ]),
        SettingsSection(header: R.string.localizable.setting_notification_badge(), rows: [
            countUnreadMessageRow
        ])
    ])
    
    private var showNotifications: Bool {
        AppGroupUserDefaults.User.showMessageNotification
    }
    private var showGroupNotifications: Bool {
        AppGroupUserDefaults.User.showGroupMessageNotification
    }
    private var showMessagePreview: Bool {
        AppGroupUserDefaults.User.showMessagePreviewInNotification
    }
    private var showGroupMessagePreview: Bool {
        AppGroupUserDefaults.User.showGroupMessagePreviewInNotification
    }
    private var countUnreadMessage: Bool {
        AppGroupUserDefaults.User.countUnreadMessages
    }
    
    class func instance() -> UIViewController {
        let vc = NotificationSettingViewController()
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.setting_notification())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource.tableView = tableView
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(switchMessagePreview(_:)),
                                               name: SettingsRow.accessoryDidChangeNotification,
                                               object: nil)
    }
    
    @objc func switchMessagePreview(_ notification: Notification) {
        guard let row = notification.object as? SettingsRow else {
            return
        }
        guard case let .switch(isOn, _) = row.accessory else {
            return
        }
        switch row {
        case showNotificationRow:
            AppGroupUserDefaults.User.showMessageNotification = isOn
            showMessagePreviewRow.accessory = .switch(isOn: AppGroupUserDefaults.User.showMessagePreviewInNotification, isEnabled: isOn)
        case showMessagePreviewRow:
            AppGroupUserDefaults.User.showMessagePreviewInNotification = isOn
        case showGroupNotificationRow:
            AppGroupUserDefaults.User.showGroupMessageNotification = isOn
            showGroupMessagePreviewRow.accessory = .switch(isOn: AppGroupUserDefaults.User.showGroupMessagePreviewInNotification, isEnabled: isOn)
        case showGroupMessagePreviewRow:
            AppGroupUserDefaults.User.showGroupMessagePreviewInNotification = isOn
        default:
            AppGroupUserDefaults.User.countUnreadMessages = isOn
        }
    }
    
}
