import UIKit
import MixinServices

final class RecoveryKitViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [])
    
    private let tableHeaderView = R.nib.imageTextTableHeaderView(withOwner: nil)!
    private let tableFooterView = RecoveryKitFooterView()
    
    private var account: Account?
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.recovery_kit()
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: LoginManager.accountDidChangeNotification, object: nil)
        tableHeaderView.imageView.image = R.image.recovery_header()
        tableHeaderView.textView.attributedText = .walletIntroduction()
        tableView.tableHeaderView = tableHeaderView
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
        reloadData()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableHeaderView.sizeToFit(tableView: tableView)
        reloadTableFooterView()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            tableHeaderView.sizeToFit(tableView: tableView)
            reloadTableFooterView()
        }
    }
    
    @objc private func reloadData() {
        guard let account = LoginManager.shared.account else {
            return
        }
        self.account = account
        let section = SettingsSection(rows: [
            SettingsRow(
                title: R.string.localizable.mobile_number(),
                subtitle: account.isAnonymous ? R.string.localizable.set_up() : R.string.localizable.added(),
                accessory: .disclosure
            ),
            SettingsRow(
                title: R.string.localizable.mnemonic_phrase(),
                subtitle: account.hasSaltExported ? R.string.localizable.backed_up() : R.string.localizable.not_backed_up(),
                accessory: .disclosure
            ),
            SettingsRow(
                title: R.string.localizable.emergency_contact(),
                subtitle: account.hasEmergencyContact ? R.string.localizable.added() : R.string.localizable.set_up(),
                accessory: .disclosure
            ),
        ])
        dataSource.reloadSections([section])
    }
    
    private func reloadTableFooterView() {
        tableView.tableFooterView = nil
        tableView.layoutIfNeeded()
        let sizeToFit = CGSize(width: view.bounds.width, height: UIView.layoutFittingExpandedSize.height)
        let contentSize = tableFooterView.sizeThatFits(sizeToFit)
        let emptyHeight = tableView.frame.height - tableView.safeAreaInsets.vertical - tableView.contentSize.height
        tableFooterView.frame.size = CGSize(width: contentSize.width, height: max(contentSize.height, emptyHeight))
        tableView.tableFooterView = tableFooterView
    }
    
}

extension RecoveryKitViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let account else {
            return
        }
        let next: UIViewController
        switch indexPath.row {
        case 0:
            next = if let number = account.phone, !account.isAnonymous {
                ChangeMobileNumberViewController(phoneNumber: number)
            } else {
                AddMobileNumberViewController()
            }
        case 1:
            next = ExportMnemonicPhrasesViewController()
        default:
            if account.isAnonymous {
                let tip = PopupTipViewController(tip: .addMobileNumber(.setRecoveryContact))
                present(tip, animated: true)
                return
            } else if account.hasEmergencyContact {
                next = ViewRecoveryContactViewController()
            } else {
                next = AddRecoveryContactViewController()
            }
        }
        navigationController?.pushViewController(next, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    
}
