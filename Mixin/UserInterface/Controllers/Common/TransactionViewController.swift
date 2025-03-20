import UIKit
import MixinServices

class TransactionViewController: UIViewController {
    
    let tableView = UITableView()
    let tableHeaderView = R.nib.snapshotTableHeaderView(withOwner: nil)!
    
    var rows: [Row] = []
    
    var iconView: BadgeIconView {
        tableHeaderView.iconView
    }
    
    var amountLabel: UILabel {
        tableHeaderView.amountLabel
    }
    
    var symbolLabel: UILabel {
        tableHeaderView.symbolLabel
    }
    
    var fiatMoneyValueLabel: UILabel {
        tableHeaderView.fiatMoneyValueLabel
    }
    
    override var canBecomeFirstResponder: Bool {
        true
    }
    
    override func loadView() {
        self.view = tableView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = .tintedIcon(
            image: R.image.customer_service(),
            target: self,
            action: #selector(customerService(_:))
        )
        tableView.backgroundColor = .background
        tableView.separatorStyle = .none
        tableView.tableHeaderView = tableHeaderView
        tableView.register(R.nib.snapshotColumnCell)
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateTableViewContentInsetBottom()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            DispatchQueue.main.async {
                self.layoutTableHeaderView()
                self.tableView.tableHeaderView = self.tableHeaderView
            }
        }
    }
    
    func layoutTableHeaderView() {
        let targetSize = CGSize(width: AppDelegate.current.mainWindow.bounds.width,
                                height: UIView.layoutFittingExpandedSize.height)
        tableHeaderView.frame.size.height = tableHeaderView.systemLayoutSizeFitting(targetSize).height
    }
    
    func updateTableViewContentInsetBottom() {
        if view.safeAreaInsets.bottom > 20 {
            tableView.contentInset.bottom = 0
        } else {
            tableView.contentInset.bottom = 20
        }
    }
    
    func fiatMoneyValue(amount: Decimal, usdPrice: Decimal) -> String {
        CurrencyFormatter.localizedString(
            from: amount * usdPrice * Currency.current.decimalRate,
            format: .fiatMoney,
            sign: .never,
            symbol: .currencySymbol
        )
    }
    
    @objc private func customerService(_ sender: Any) {
        if let user = UserDAO.shared.getUser(identityNumber: "7000") {
            let conversation = ConversationViewController.instance(ownerUser: user)
            navigationController?.pushViewController(withBackRoot: conversation)
        }
    }
    
}

extension TransactionViewController {
    
    protocol RowKey {
        var allowsCopy: Bool { get }
        var localized: String { get }
    }
    
    class Row {
        
        struct Style: OptionSet {
            
            let rawValue: Int
            
            static let unavailable = Style(rawValue: 1 << 0)
            static let disclosureIndicator = Style(rawValue: 1 << 1)
            
        }
        
        let key: RowKey
        let value: String
        let style: Style
        
        init(key: RowKey, value: String, style: Style = []) {
            self.key = key
            self.value = value
            self.style = style
        }
        
    }
    
}

extension TransactionViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.snapshot_column, for: indexPath)!
        let row = rows[indexPath.row]
        cell.titleLabel.text = row.key.localized.localizedUppercase
        cell.subtitleLabel.text = row.value
        if row.style.contains(.unavailable) {
            cell.subtitleLabel.textColor = R.color.text_tertiary()!
        } else {
            cell.subtitleLabel.textColor = R.color.text()
        }
        cell.disclosureIndicatorImageView.isHidden = !row.style.contains(.disclosureIndicator)
        return cell
    }
    
}

extension TransactionViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
        rows[indexPath.row].key.allowsCopy
    }
    
    func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        rows[indexPath.row].key.allowsCopy && action == #selector(copy(_:))
    }
    
    func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
        UIPasteboard.general.string = rows[indexPath.row].value
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
    }
    
}
