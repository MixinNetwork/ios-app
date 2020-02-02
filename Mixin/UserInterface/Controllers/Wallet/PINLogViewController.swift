import UIKit
import MixinServices

class PINLogViewController: UITableViewController {

    private let loadNextPageThreshold = 20
    private var logs = [PINLogResponse]()
    private var isLoading = false
    private var isPageEnded = false

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(R.nib.pinLogCell)
        fetchLogs()
    }

    private func fetchLogs(offset: String? = nil) {
        guard !isLoading else {
            return
        }
        isLoading = true
        AccountAPI.shared.pinLogs(offset: logs.last?.createdAt) { [weak self](result) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.isLoading = false
            switch result{
            case let .success(logs):
                if logs.count < weakSelf.loadNextPageThreshold {
                    weakSelf.isPageEnded = true
                }
                weakSelf.logs += logs
                weakSelf.tableView.reloadData()
                weakSelf.tableView.checkEmpty(dataCount: weakSelf.logs.count, text: R.string.localizable.wallet_pin_logs_empty(), photo: R.image.wallet.ic_no_transaction()!)
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
    }

    class func instance() -> UIViewController {
        let vc = R.storyboard.wallet.pin_logs()!
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.wallet_pin_logs())
        return container
    }

}

extension PINLogViewController {

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return logs.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.pin_logs, for: indexPath)!
        let log = logs[indexPath.row]
        cell.titleLabel.text = getDescription(by: log.code)
        cell.ipLabel.text = log.ipAddress
        cell.timeLabel.text = log.createdAt.toUTCDate().logDatetime()
        return cell
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

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard logs.count - indexPath.row < loadNextPageThreshold, !isPageEnded else {
            return
        }
        fetchLogs()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
