import UIKit
import MixinServices

class RowListViewController: UIViewController {
    
    let tableView = UITableView()
    var tableHeaderView: UIView!
    
    var rows: [Row] = []
    
    override var canBecomeFirstResponder: Bool {
        true
    }
    
    override func loadView() {
        self.view = tableView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.backgroundColor = .background
        tableView.separatorStyle = .none
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
    
}


extension RowListViewController: ContainerViewControllerDelegate {
    
    var prefersNavigationBarSeparatorLineHidden: Bool {
        return true
    }
    
    func imageBarRightButton() -> UIImage? {
        R.image.customer_service()
    }
    
    func barRightButtonTappedAction() {
        if let user = UserDAO.shared.getUser(identityNumber: "7000") {
            let conversation = ConversationViewController.instance(ownerUser: user)
            navigationController?.pushViewController(withBackRoot: conversation)
        }
    }
    
}

extension RowListViewController {
    
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

extension RowListViewController: UITableViewDataSource {
    
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

extension RowListViewController: UITableViewDelegate {
    
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