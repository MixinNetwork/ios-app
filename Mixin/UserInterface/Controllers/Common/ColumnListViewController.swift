import UIKit
import MixinServices

class ColumnListViewController: UIViewController {
    
    let tableView = UITableView()
    var tableHeaderView: UIView!

    var columns: [Column] = []
    
    override var canBecomeFirstResponder: Bool {
        true
    }
    
    override func loadView() {
        self.view = tableView
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
    
    func deselectRow(column: Column) {
        
    }
}


extension ColumnListViewController: ContainerViewControllerDelegate {
    
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

extension ColumnListViewController {
    
    protocol ColumnKey {
        
        var allowCopy: Bool { get }
        
        var localized: String { get }
        
    }

    class Column {
        
        struct Style: OptionSet {
            
            let rawValue: Int
            
            static let unavailable = Style(rawValue: 1 << 0)
            static let disclosureIndicator = Style(rawValue: 1 << 1)
            
        }
        
        let key: ColumnKey
        let value: String
        let style: Style
        
        init(key: ColumnKey, value: String, style: Style = []) {
            self.key = key
            self.value = value
            self.style = style
        }
        
    }
    
}

extension ColumnListViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        deselectRow(column: columns[indexPath.row])
    }
    
    func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
        columns[indexPath.row].key.allowCopy
    }
    
    func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        columns[indexPath.row].key.allowCopy && action == #selector(copy(_:))
    }
    
    func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
        UIPasteboard.general.string = columns[indexPath.row].value
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
    }
    
}

extension ColumnListViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return columns.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.snapshot_column, for: indexPath)!
        let column = columns[indexPath.row]
        cell.titleLabel.text = column.key.localized.localizedUppercase
        cell.subtitleLabel.text = column.value
        if column.style.contains(.unavailable) {
            cell.subtitleLabel.textColor = R.color.text_tertiary()!
        } else {
            cell.subtitleLabel.textColor = R.color.text()
        }
        cell.disclosureIndicatorImageView.isHidden = !column.style.contains(.disclosureIndicator)
        return cell
    }
    
}
