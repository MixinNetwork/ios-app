import UIKit

class DesktopViewController: UITableViewController {
    
    @IBOutlet weak var actionCell: UITableViewCell!
    @IBOutlet weak var indicatorView: ActivityIndicatorView!
    @IBOutlet weak var actionLabel: UILabel!
    @IBOutlet weak var footerLabel: UILabel!
    
    class func instance() -> UIViewController {
        let vc = Storyboard.setting.instantiateViewController(withIdentifier: "desktop") as! DesktopViewController
        let container = ContainerViewController.instance(viewController: vc, title: Localized.SETTING_DESKTOP)
        container.automaticallyAdjustsScrollViewInsets = false
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(sessionChanged), name: .UserSessionDidChange, object: nil)
        updateLabels(isDesktopLoggedIn: AccountUserDefault.shared.isDesktopLoggedIn)
        actionCell.selectedBackgroundView = UIView.createSelectedBackgroundView()
    }
    
    @objc func sessionChanged() {
        updateLabels(isDesktopLoggedIn: AccountUserDefault.shared.isDesktopLoggedIn)
        layoutForIsLoading(false)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let sessionId = AccountUserDefault.shared.extensionSession {
            guard !indicatorView.isAnimating else {
                return
            }
            layoutForIsLoading(true)
            AccountAPI.shared.logoutSession(sessionId: sessionId) { [weak self](result) in
                guard let weakSelf = self else {
                    return
                }

                weakSelf.layoutForIsLoading(false)
                switch result {
                case .success:
                    weakSelf.updateLabels(isDesktopLoggedIn: false)
                case let .failure(error):
                    showHud(style: .error, text: error.localizedDescription)
                }
            }
        } else {
            let vc = CameraViewController.instance()
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func layoutForIsLoading(_ isLoading: Bool) {
        actionCell.isUserInteractionEnabled = !isLoading
        actionLabel.isHidden = isLoading
        indicatorView.isAnimating = isLoading
    }
    
    func updateLabels(isDesktopLoggedIn: Bool) {
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
