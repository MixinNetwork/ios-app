import UIKit
import MixinServices

class PINLogViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityIndicator: ActivityIndicatorView!
    
    @IBOutlet weak var showActivityIndicatorConstraint: NSLayoutConstraint!
    @IBOutlet weak var hideActivityIndicatorConstraint: NSLayoutConstraint!
    
    private let loadNextPageThreshold = 20
    private var logs = [PINLogResponse]()
    private var isLoading = false
    private var isPageEnded = false
    
    class func instance() -> UIViewController {
        let vc = R.storyboard.wallet.pin_logs()!
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.wallet_pin_logs())
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
        AccountAPI.shared.pinLogs(offset: logs.last?.createdAt) { [weak self](result) in
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
                                          text: R.string.localizable.wallet_pin_logs_empty(),
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
    
    private func getDescription(by code: String) -> String {
        switch code {
        case "VERIFICATION":
            return R.string.localizable.pin_log_verification()
        case "RAW_TRANSFER":
            return R.string.localizable.pin_log_raw_transfer()
        case "USER_TRANSFER":
            return R.string.localizable.pin_log_user_transfer()
        case "WITHDRAWAL":
            return R.string.localizable.pin_log_withdrawal()
        case "ADD_ADDRESS":
            return R.string.localizable.pin_log_add_address()
        case "DELETE_ADDRESS":
            return R.string.localizable.pin_log_delete_address()
        case "ADD_EMERGENCY":
            return R.string.localizable.pin_log_add_emergency()
        case "DELETE_EMERGENCY":
            return R.string.localizable.pin_log_delete_emergency()
        case "READ_EMERGENCY":
            return R.string.localizable.pin_log_read_emergency()
        case "UPDATE_PHONE":
            return R.string.localizable.pin_log_update_phone()
        case "UPDATE_PIN":
            return R.string.localizable.pin_log_update_pin()
        case "MULTISIG_SIGN":
            return R.string.localizable.pin_log_multisig_sign()
        case "MULTISIG_UNLOCK":
            return R.string.localizable.pin_log_multisig_unlock()
        default:
            return code
        }
    }
    
}

extension PINLogViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return logs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.pin_logs, for: indexPath)!
        let log = logs[indexPath.row]
        cell.titleLabel.text = getDescription(by: log.code)
        cell.ipLabel.text = log.ipAddress
        cell.timeLabel.text = log.createdAt.toUTCDate().logDatetime()
        return cell
    }
    
}

extension PINLogViewController: UITableViewDelegate {
    
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
