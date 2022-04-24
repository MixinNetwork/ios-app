import UIKit
import MixinServices

class LogViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityIndicator: ActivityIndicatorView!
    
    @IBOutlet weak var showActivityIndicatorConstraint: NSLayoutConstraint!
    @IBOutlet weak var hideActivityIndicatorConstraint: NSLayoutConstraint!
    
    private let loadNextPageThreshold = 20
    private var logs = [LogResponse]()
    private var isLoading = false
    private var isPageEnded = false
    private var category: AccountAPI.LogCategory = .all

    class func instance(category: AccountAPI.LogCategory) -> UIViewController {
        let vc = R.storyboard.wallet.logs()!
        vc.category = category
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.logs())
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        fetchLogs()
    }
    
    private func fetchLogs(offset: String? = nil) {
        guard !isLoading else {
            return
        }
        isLoading = true
        AccountAPI.logs(offset: logs.last?.createdAt, category: category) { [weak self](result) in
            guard let self = self else {
                return
            }
            self.isLoading = false
            switch result{
            case let .success(logs):
                if logs.count < self.loadNextPageThreshold {
                    self.isPageEnded = true
                }
                self.logs += logs
                self.tableView.reloadData()
                self.tableView.checkEmpty(dataCount: self.logs.count,
                                          text: R.string.localizable.no_logs(),
                                          photo: R.image.emptyIndicator.ic_data()!)
                self.view.layoutIfNeeded()
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
            if self.activityIndicator.isAnimating {
                self.activityIndicator.stopAnimating()
                self.hideActivityIndicatorConstraint.priority = .defaultHigh
                UIView.animate(withDuration: 0.3) {
                    self.view.layoutIfNeeded()
                }
            }
        }
    }
    
    private func getDescription(by code: String) -> (String, String) {
        switch code {
        case "VERIFICATION":
            return (R.string.localizable.pin_incorrect(), R.string.localizable.verify())
        case "RAW_TRANSFER":
            return (R.string.localizable.pin_incorrect(), R.string.localizable.transfer_to_Mixin_address())
        case "USER_TRANSFER":
            return (R.string.localizable.pin_incorrect(), R.string.localizable.transfer_to_user_or_bot())
        case "WITHDRAWAL":
            return (R.string.localizable.pin_incorrect(), R.string.localizable.withdrawal())
        case "ADD_ADDRESS":
            return (R.string.localizable.pin_incorrect(), R.string.localizable.add_address())
        case "DELETE_ADDRESS":
            return (R.string.localizable.pin_incorrect(), R.string.localizable.delete_address())
        case "ADD_EMERGENCY":
            return (R.string.localizable.pin_incorrect(), R.string.localizable.add_emergency_contact())
        case "DELETE_EMERGENCY":
            return (R.string.localizable.pin_incorrect(), R.string.localizable.delete_emergency_contact())
        case "READ_EMERGENCY":
            return (R.string.localizable.pin_incorrect(), R.string.localizable.view_emergency_contact())
        case "UPDATE_PHONE":
            return (R.string.localizable.pin_incorrect(), R.string.localizable.change_Phone_Number())
        case "UPDATE_PIN":
            return (R.string.localizable.pin_incorrect(), R.string.localizable.change_PIN())
        case "MULTISIG_SIGN":
            return (R.string.localizable.pin_incorrect(), R.string.localizable.multisig_Transaction())
        case "MULTISIG_UNLOCK":
            return (R.string.localizable.pin_incorrect(), R.string.localizable.revoke_multisig_transaction())
        case "ACTIVITY_PIN_MODIFICATION":
            return (R.string.localizable.pin_change(), R.string.localizable.your_PIN_has_been_changed())
        case "ACTIVITY_EMERGENCY_CONTACT_MODIFICATION":
            return (R.string.localizable.emergency_Contact(), R.string.localizable.your_emergency_contact_has_been_changed())
        case "ACTIVITY_PHONE_MODIFICATION":
            return (R.string.localizable.phone_number_change(), R.string.localizable.your_phone_number_has_been_changed())
        case "ACTIVITY_LOGIN_BY_PHONE":
            return (R.string.localizable.sign_in(), R.string.localizable.sign_with_phone_number())
        case "ACTIVITY_LOGIN_BY_EMERGENCY_CONTACT":
            return (R.string.localizable.sign_in(), R.string.localizable.sign_with_emergency_contact())
        case "ACTIVITY_LOGIN_FROM_DESKTOP":
            return (R.string.localizable.sign_in(), R.string.localizable.desktop_on_hint())
        default:
            return (code, code)
        }
    }
    
}

extension LogViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return logs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.pin_logs, for: indexPath)!
        let log = logs[indexPath.row]
        (cell.titleLabel.text, cell.descLabel.text) = getDescription(by: log.code)
        cell.ipLabel.text = log.ipAddress
        cell.timeLabel.text = log.createdAt.toUTCDate().logDatetime()
        return cell
    }
    
}

extension LogViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard logs.count - indexPath.row < loadNextPageThreshold, !isPageEnded else {
            return
        }
        fetchLogs()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
}
