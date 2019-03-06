import UIKit

class DesktopViewController: UITableViewController {
    
    @IBOutlet weak var statusImageView: UIImageView!
    @IBOutlet weak var actionLabel: UILabel!
    @IBOutlet weak var indicatorView: UIActivityIndicatorView!
    @IBOutlet weak var actionCell: UITableViewCell!

    private let cellReuseId = "cell"
    private var isDesktopLoggedIn = AccountUserDefault.shared.isDesktopLoggedIn
    
    class func instance() -> UIViewController {
        let vc = Storyboard.setting.instantiateViewController(withIdentifier: "desktop") as! DesktopViewController
        return ContainerViewController.instance(viewController: vc, title: Localized.SETTING_DESKTOP)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(sessionChanged), name: .UserSessionDidChange, object: nil)
        updateStatus(forceUpdate: true)
    }

    @objc func sessionChanged() {
        updateStatus()
    }
    
    private func updateStatus(forceUpdate: Bool = false) {
        let isDesktopLoggedIn = AccountUserDefault.shared.isDesktopLoggedIn
        guard forceUpdate || self.isDesktopLoggedIn != isDesktopLoggedIn else {
            return
        }
        self.isDesktopLoggedIn = isDesktopLoggedIn

        statusImageView.image = isDesktopLoggedIn ? UIImage(named: "ic_desktop_on") : UIImage(named: "ic_desktop_off")
        actionLabel.text = isDesktopLoggedIn ? Localized.SETTING_DESKTOP_LOG_OUT : Localized.SCAN_QR_CODE

        if !forceUpdate {
            actionLabel.isHidden = false
            indicatorView.stopAnimating()
            indicatorView.isHidden = true
            actionCell.isUserInteractionEnabled = true
        }
    }

    private func loadingView() {
        guard !indicatorView.isAnimating else {
            return
        }
        actionCell.isUserInteractionEnabled = false
        actionLabel.isHidden = true
        indicatorView.startAnimating()
        indicatorView.isHidden = false
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if AccountUserDefault.shared.isDesktopLoggedIn {
            loadingView()
            AccountAPI.shared.logoutSession { (_) in

            }
        } else {
            let vc = CameraViewController.instance()
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}
