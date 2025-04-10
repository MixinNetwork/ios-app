import UIKit
import MixinServices

class TransactionViewController: UIViewController {
    
    let tableView = UITableView()
    
    var viewOnExplorerURL: URL? {
        nil
    }
    
    override var canBecomeFirstResponder: Bool {
        true
    }
    
    override func loadView() {
        self.view = tableView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItems = [
            .tintedIcon(
                image: R.image.ic_title_more(),
                target: self,
                action: #selector(presentMoreActions(_:))
            ),
            .customerService(
                target: self,
                action: #selector(presentCustomerService(_:))
            ),
        ]
        tableView.backgroundColor = .background
        tableView.separatorStyle = .none
        tableView.register(R.nib.snapshotColumnCell)
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateTableViewContentInsetBottom()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            DispatchQueue.main.async {
                guard let tableHeaderView = self.tableView.tableHeaderView else {
                    return
                }
                self.layoutTableHeaderView()
                self.tableView.tableHeaderView = tableHeaderView
            }
        }
    }
    
    func layoutTableHeaderView() {
        guard let tableHeaderView = tableView.tableHeaderView else {
            return
        }
        let targetSize = CGSize(
            width: AppDelegate.current.mainWindow.bounds.width,
            height: UIView.layoutFittingExpandedSize.height
        )
        let layoutSize = tableHeaderView.systemLayoutSizeFitting(targetSize)
        tableHeaderView.frame.size.height = layoutSize.height
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
    
    @objc func presentMoreActions(_ sender: Any) {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: R.string.localizable.view_on_explorer(), style: .default, handler: { _ in
            guard let url = self.viewOnExplorerURL else {
                return
            }
            UIApplication.shared.open(url)
        }))
        sheet.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel))
        present(sheet, animated: true)
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        if let user = UserDAO.shared.getUser(identityNumber: "7000") {
            let conversation = ConversationViewController.instance(ownerUser: user)
            navigationController?.pushViewController(withBackRoot: conversation)
        }
    }
    
}
