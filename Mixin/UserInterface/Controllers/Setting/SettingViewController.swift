import UIKit

class SettingViewController: UITableViewController {

    @IBOutlet weak var logoutLoadingView: UIActivityIndicatorView!
    @IBOutlet weak var logoutLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        logoutLoadingView.isHidden = true
    }

    class func instance() -> UIViewController {
        return ContainerViewController.instance(viewController: Storyboard.setting.instantiateInitialViewController()!, title: Localized.SETTING_TITLE)
    }
}

extension SettingViewController {

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch indexPath.section {
        case 0:
            navigationController?.pushViewController(PrivacyViewController.instance(), animated: true)
        case 2:
            alert(Localized.ABOUT_LOGOUT_TITLE, message: Localized.ABOUT_LOGOUT_MESSAGE, actionTitle: Localized.SETTING_LOGOUT, handler: { [weak self] (action) in
                self?.logoutAction()
            })
        default:
            navigationController?.pushViewController(AboutContainerViewController.instance(), animated: true)
        }
    }

    private func logoutAction() {
        logoutLoadingView.startAnimating()
        logoutLabel.isHidden = true
        logoutLoadingView.isHidden = false
        AccountAPI.shared.logout(completion: { [weak self](result) in
            self?.logoutLoadingView.stopAnimating()
            self?.logoutLabel.isHidden = false
            self?.logoutLoadingView.isHidden = true
            
            switch result {
            case .success:
                AccountAPI.shared.logout()
            case .failure:
                break
            }
        })
    }
}
