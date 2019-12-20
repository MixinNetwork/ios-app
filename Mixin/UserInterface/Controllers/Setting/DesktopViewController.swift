import UIKit

class DesktopViewController: UITableViewController {
    
    @IBOutlet weak var actionCell: ModernSelectedBackgroundCell!
    @IBOutlet weak var indicatorView: ActivityIndicatorView!
    @IBOutlet weak var actionLabel: UILabel!
    @IBOutlet weak var footerLabel: UILabel!
    
    class func instance() -> UIViewController {
        let vc = R.storyboard.setting.desktop()!
        let container = ContainerViewController.instance(viewController: vc, title: Localized.SETTING_DESKTOP)
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(sessionChanged), name: .UserSessionDidChange, object: nil)
        updateLabels(isDesktopLoggedIn: AppGroupUserDefaults.Account.isDesktopLoggedIn)
    }
    
    @objc func sessionChanged() {
        updateLabels(isDesktopLoggedIn: AppGroupUserDefaults.Account.isDesktopLoggedIn)
        layoutForIsLoading(false)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let sessionId = AppGroupUserDefaults.Account.extensionSession {
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
                    showAutoHiddenHud(style: .error, text: error.localizedDescription)
                }
            }
        } else {
            let vc = CameraViewController.instance()
            vc.scanQrCodeOnly = true
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
            if let lastLoginDate = AppGroupUserDefaults.Account.lastDesktopLoginDate {
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
