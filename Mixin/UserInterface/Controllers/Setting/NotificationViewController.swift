import UIKit

class NotificationViewController: UITableViewController {


    class func instance() -> UIViewController {
        return ContainerViewController.instance(viewController: Storyboard.setting.instantiateViewController(withIdentifier: "notification"), title: Localized.SETTING_TITLE)
    }

}

extension NotificationViewController {

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return Localized.SETTING_NOTIFICATION_MESSAGE
        default:
            return Localized.SETTING_NOTIFICATION_GROUP
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            return Localized.SETTING_NOTIFICATION_MESSAGE_SUMMARY
        default:
            return Localized.SETTING_NOTIFICATION_GROUP_SUMMARY
        }
    }
}
