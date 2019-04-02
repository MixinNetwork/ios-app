import UIKit

class DesktopViewController: UITableViewController {
    
    @IBOutlet weak var actionCell: UITableViewCell!
    @IBOutlet weak var indicatorView: UIActivityIndicatorView!
    @IBOutlet weak var actionLabel: UILabel!
    @IBOutlet weak var footerLabel: UILabel!
    
    private var isDesktopLoggedIn: Bool {
        return AccountUserDefault.shared.isDesktopLoggedIn
    }
    
    class func instance() -> UIViewController {
        let vc = Storyboard.setting.instantiateViewController(withIdentifier: "desktop") as! DesktopViewController
        let container = ContainerViewController.instance(viewController: vc, title: Localized.SETTING_DESKTOP)
        container.automaticallyAdjustsScrollViewInsets = false
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(sessionChanged), name: .UserSessionDidChange, object: nil)
        updateLabels()
        actionCell.selectedBackgroundView = UIView.createSelectedBackgroundView()
    }
    
    @objc func sessionChanged() {
        updateLabels()
        layoutForIsLoading(false)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let sessionId = AccountUserDefault.shared.extensionSession {
            layoutForIsLoading(true)
            AccountAPI.shared.logoutSession(sessionId: sessionId, completion: { _ in })
        } else {
            let vc = CameraViewController.instance()
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    private func layoutForIsLoading(_ isLoading: Bool) {
        actionCell.isUserInteractionEnabled = !isLoading
        actionLabel.isHidden = isLoading
        isLoading ? indicatorView.startAnimating() : indicatorView.stopAnimating()
        indicatorView.isHidden = !isLoading
    }
    
    private func updateLabels() {
        if isDesktopLoggedIn {
            actionLabel.text = Localized.SETTING_DESKTOP_LOG_OUT
            footerLabel.text = Localized.SETTING_DESKTOP_DESKTOP_ON
        } else {
            actionLabel.text = Localized.SCAN_QR_CODE
            if let lastLoginDate = AccountUserDefault.shared.lastDesktopLogin {
                let time = formattedString(from: lastLoginDate)
                footerLabel.text = Localized.SETTING_DESKTOP_LAST_ACTIVE(time: time)
            } else {
                footerLabel.text = nil
            }
        }
    }
    
    private func formattedString(from date: Date) -> String {
        let secondsPerWeek: TimeInterval = 7 * 24 * 60 * 60
        let formatter: DateFormatter
        if date.timeIntervalSinceNow < secondsPerWeek {
            formatter = DateFormatter.nameOfTheDayAndTime
        } else {
            formatter = DateFormatter.dateAndTime
        }
        return formatter.string(from: date)
    }
    
}
