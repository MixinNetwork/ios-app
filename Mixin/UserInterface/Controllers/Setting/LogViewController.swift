import UIKit
import MixinServices

final class LogViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityIndicator: ActivityIndicatorView!
    
    @IBOutlet weak var showActivityIndicatorConstraint: NSLayoutConstraint!
    @IBOutlet weak var hideActivityIndicatorConstraint: NSLayoutConstraint!
    
    private let category: AccountLog.Category
    private let loadNextPageThreshold = 20
    
    private var logs: [LogViewModel] = []
    private var isLoading = false
    private var isPageEnded = false
    
    init(category: AccountLog.Category) {
        self.category = category
        let nib = R.nib.logView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.logs()
        if navigationController?.presentingViewController != nil {
            navigationItem.leftBarButtonItem = .tintedIcon(
                image: R.image.ic_title_close(),
                target: self,
                action: #selector(close(_:))
            )
        }
        tableView.register(R.nib.logCell)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        fetchLogs()
    }
    
    @objc private func close(_ sender: Any) {
        navigationController?.presentingViewController?.dismiss(animated: true)
    }
    
    private func fetchLogs(offset: String? = nil) {
        guard !isLoading else {
            return
        }
        isLoading = true
        AccountAPI.logs(category: category, offset: offset) { [weak self] (result) in
            guard let self = self else {
                return
            }
            self.isLoading = false
            switch result {
            case let .success(logs):
                if logs.count < self.loadNextPageThreshold {
                    self.isPageEnded = true
                }
                self.logs += logs.map(LogViewModel.init(log:))
                self.tableView.reloadData()
                self.tableView.checkEmpty(
                    dataCount: self.logs.count,
                    text: R.string.localizable.no_logs(),
                    photo: R.image.emptyIndicator.ic_data()!
                )
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
    
}

extension LogViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return logs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.account_log, for: indexPath)!
        let log = logs[indexPath.row]
        cell.titleLabel.text = log.title
        cell.descriptionLabel.text = log.description
        cell.ipAddressLabel.text = log.ipAddress
        if let location = log.ipLocation {
            cell.ipLocationLabel.text = location
            cell.ipLocationLabel.isHidden = false
        } else {
            cell.ipLocationLabel.isHidden = true
        }
        cell.timeLabel.text = log.date
        return cell
    }
    
}

extension LogViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard logs.count - indexPath.row < loadNextPageThreshold, !isPageEnded else {
            return
        }
        fetchLogs(offset: logs.last?.offset)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
}

extension LogViewController {
    
    private struct LogViewModel {
        
        let title: String
        let date: String
        let description: String
        let ipLocation: String?
        let ipAddress: String
        let offset: String
        
        init(log: AccountLog) {
            (title, description) = switch log.code {
            case "ACTIVITY_LOGIN_FROM_DESKTOP":
                (R.string.localizable.pin_log_title_sign_in_on_desktop(), R.string.localizable.pin_log_subtitle_signed_in_on_desktop())
            case "ACTIVITY_LOGIN_BY_PHONE":
                (R.string.localizable.pin_log_title_sign_in_on_mobile(), R.string.localizable.pin_log_subtitle_signed_in_via_mobile_number())
            case "ACTIVITY_LOGIN_BY_MNEMONIC":
                (R.string.localizable.pin_log_title_sign_in_on_mobile(), R.string.localizable.pin_log_subtitle_signed_in_via_mnemonic_phrase())
            case "ACTIVITY_LOGIN_BY_EMERGENCY_CONTACT":
                (R.string.localizable.pin_log_title_sign_in_on_mobile(), R.string.localizable.pin_log_subtitle_signed_in_via_recovery_contact())
            case "ACTIVITY_LOGOUT_PHONE":
                (R.string.localizable.pin_log_title_sign_out_on_mobile(), R.string.localizable.pin_log_subtitle_signed_out_on_mobile())
            case "ACTIVITY_LOGOUT_DESKTOP":
                (R.string.localizable.pin_log_title_sign_out_on_desktop(), R.string.localizable.pin_log_subtitle_signed_out_on_desktop())
            case "UPGRADE_SAFE":
                (R.string.localizable.pin_log_title_upgrade_safe(), R.string.localizable.pin_log_subtitle_account_upgraded())
                
            case "UPDATE_PIN":
                (R.string.localizable.pin_log_title_change_pin(), R.string.localizable.pin_log_subtitle_pin_incorrect())
            case "VERIFICATION":
                (R.string.localizable.pin_log_title_verify_pin(), R.string.localizable.pin_log_subtitle_pin_incorrect())
            case "RAW_TRANSFER", "USER_TRANSFER":
                (R.string.localizable.pin_log_title_transfer(), R.string.localizable.pin_log_subtitle_pin_incorrect())
            case "WITHDRAWAL":
                (R.string.localizable.pin_log_title_withdrawal(), R.string.localizable.pin_log_subtitle_pin_incorrect())
            case "ADD_EMERGENCY":
                (R.string.localizable.pin_log_title_add_recovery_contact(), R.string.localizable.pin_log_subtitle_pin_incorrect())
            case "DELETE_EMERGENCY":
                (R.string.localizable.pin_log_title_delete_recovery_contact(), R.string.localizable.pin_log_subtitle_pin_incorrect())
            case "READ_EMERGENCY":
                (R.string.localizable.pin_log_title_view_recovery_contact(), R.string.localizable.pin_log_subtitle_pin_incorrect())
            case "ADD_ADDRESS":
                (R.string.localizable.pin_log_title_add_address(), R.string.localizable.pin_log_subtitle_pin_incorrect())
            case "DELETE_ADDRESS":
                (R.string.localizable.pin_log_title_delete_address(), R.string.localizable.pin_log_subtitle_pin_incorrect())
            case "UPDATE_PHONE":
                (R.string.localizable.pin_log_title_update_mobile_number(), R.string.localizable.pin_log_subtitle_pin_incorrect())
            case "MULTISIG_SIGN":
                (R.string.localizable.pin_log_title_sign_multisig_transaction(), R.string.localizable.pin_log_subtitle_pin_incorrect())
            case "MULTISIG_UNLOCK":
                (R.string.localizable.pin_log_title_revoke_multisig_transaction(), R.string.localizable.pin_log_subtitle_pin_incorrect())
            case "LOGIN_FROM_DESKTOP":
                (R.string.localizable.pin_log_title_sign_in_on_desktop(), R.string.localizable.pin_log_subtitle_pin_incorrect())
            case "COLLECTIBLE_SIGN":
                (R.string.localizable.pin_log_title_inscribe_collectible(), R.string.localizable.pin_log_subtitle_pin_incorrect())
            case "COLLECTIBLE_UNLOCK":
                (R.string.localizable.pin_log_title_release_collectible(), R.string.localizable.pin_log_subtitle_pin_incorrect())
            case "DO_AUTHORIZATION":
                (R.string.localizable.pin_log_title_authorize_bot(), R.string.localizable.pin_log_subtitle_pin_incorrect())
            case "APP_OWNERSHIP_TRANSFER":
                (R.string.localizable.pin_log_title_transfer_bot_ownership(), R.string.localizable.pin_log_subtitle_pin_incorrect())
            case "DELETE_ACCOUNT":
                (R.string.localizable.pin_log_title_delete_account(), R.string.localizable.pin_log_subtitle_pin_incorrect())
                
            case "ACTIVITY_PIN_CREATION":
                (R.string.localizable.pin_log_title_set_pin(), R.string.localizable.pin_log_subtitle_pin_set())
            case "ACTIVITY_PIN_MODIFICATION":
                (R.string.localizable.pin_log_title_change_pin(), R.string.localizable.pin_log_subtitle_pin_changed())
            case "ACTIVITY_EMERGENCY_CONTACT_MODIFICATION":
                (R.string.localizable.pin_log_title_change_recovery_contact(), R.string.localizable.pin_log_subtitle_recovery_contact_changed())
            case "USER_EXPORT_PRIVATE":
                (R.string.localizable.pin_log_title_export_mnemonic_phrase(), R.string.localizable.pin_log_subtitle_mnemonic_phrase_exported())
            case "ACTIVITY_PHONE_MODIFICATION":
                (R.string.localizable.pin_log_title_change_mobile_number(), R.string.localizable.pin_log_subtitle_mobile_number_changed())
                
            default:
                (log.code, log.code)
            }
            date = DateFormatter.log.string(from: log.createdAt.toUTCDate())
            ipLocation = log.ipLocation.isEmpty ? nil : log.ipLocation
            ipAddress = log.ipAddress
            offset = log.createdAt
        }
        
    }
    
}
