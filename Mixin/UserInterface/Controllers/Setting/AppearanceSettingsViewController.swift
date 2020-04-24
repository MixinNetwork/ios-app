import UIKit
import MixinServices

class AppearanceSettingsViewController: SettingsTableViewController {
    
    private let currencyRow = SettingsRow(title: R.string.localizable.wallet_currency(), accessory: .disclosure)
    
    private lazy var dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [currencyRow])
    ])
    
    class func instance() -> UIViewController {
        let vc = AppearanceSettingsViewController()
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.setting_appearance())
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateCurrencySubtitle()
        NotificationCenter.default.addObserver(self, selector: #selector(updateCurrencySubtitle), name: Currency.currentCurrencyDidChangeNotification, object: nil)
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
    @objc func updateCurrencySubtitle() {
        let currency = Currency.current
        let subtitle = currency.code + " (" + currency.symbol + ")"
        currencyRow.subtitle = subtitle
    }
    
}

extension AppearanceSettingsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let vc = CurrencySelectorViewController()
        present(vc, animated: true, completion: nil)
    }
    
}
