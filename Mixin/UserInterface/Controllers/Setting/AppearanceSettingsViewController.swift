import UIKit
import MixinServices

class AppearanceSettingsViewController: SettingsTableViewController {
    
    private let currencyRow = SettingsRow(title: R.string.localizable.currency(), accessory: .disclosure)
    private let isLanguageAvailable: Bool = {
        if #available(iOS 14.0, *) {
            return true
        } else {
            return false
        }
    }()
    
    private lazy var userInterfaceStyleRow = SettingsRow(title: R.string.localizable.interface_style(), accessory: .disclosure)
    private lazy var languageRow = SettingsRow(title: R.string.localizable.language(),
                                               subtitle: R.string.localizable.english(),
                                               accessory: .disclosure)
    
    private lazy var dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [currencyRow])
    ])
    
    class func instance() -> UIViewController {
        let vc = AppearanceSettingsViewController()
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.appearance())
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateCurrencySubtitle()
        if isLanguageAvailable {
            dataSource.insertSection(SettingsSection(rows: [languageRow]), at: 0, animation: .none)
        }
        updateUserInterfaceStyleSubtitle()
        dataSource.insertSection(SettingsSection(rows: [userInterfaceStyleRow]), at: 0, animation: .none)
        NotificationCenter.default.addObserver(self, selector: #selector(updateCurrencySubtitle), name: Currency.currentCurrencyDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateUserInterfaceStyleSubtitle), name: AppGroupUserDefaults.User.didChangeUserInterfaceStyleNotification, object: nil)
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
}

extension AppearanceSettingsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 0:
            pickUserInterfaceStyle()
        case 1:
            if isLanguageAvailable {
                pickLanguage()
            } else {
                pickCurrency()
            }
        case 2:
            pickCurrency()
        default:
            break
        }
    }
    
}

extension AppearanceSettingsViewController {
    
    @objc private func updateCurrencySubtitle() {
        let currency = Currency.current
        let subtitle = currency.code + " (" + currency.symbol + ")"
        currencyRow.subtitle = subtitle
    }
    
    @objc private func updateUserInterfaceStyleSubtitle() {
        let subtitle: String
        switch AppGroupUserDefaults.User.userInterfaceStyle {
        case .light:
            subtitle = R.string.localizable.light()
        case .dark:
            subtitle = R.string.localizable.dark()
        case .unspecified:
            subtitle = R.string.localizable.automatic()
        @unknown default:
            subtitle = ""
        }
        userInterfaceStyleRow.subtitle = subtitle
    }
    
    private func pickUserInterfaceStyle() {
        let sheet = UIAlertController(title: R.string.localizable.interface_style(), message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: R.string.localizable.light(), style: .default, handler: { (_) in
            AppGroupUserDefaults.User.userInterfaceStyle = .light
        }))
        sheet.addAction(UIAlertAction(title: R.string.localizable.dark(), style: .default, handler: { (_) in
            AppGroupUserDefaults.User.userInterfaceStyle = .dark
        }))
        sheet.addAction(UIAlertAction(title: R.string.localizable.automatic(), style: .default, handler: { (_) in
            AppGroupUserDefaults.User.userInterfaceStyle = .unspecified
        }))
        sheet.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        present(sheet, animated: true, completion: nil)
    }
    
    private func pickLanguage() {
        let alert = UIAlertController(title: R.string.localizable.change_your_app_language(),
                                      message: R.string.localizable.setting_appearance_language_alert_description(),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: R.string.localizable.settings(), style: .default, handler: { (_) in
            UIApplication.openAppSettings()
        }))
        present(alert, animated: true, completion: nil)
    }
    
    private func pickCurrency() {
        let vc = CurrencySelectorViewController()
        present(vc, animated: true, completion: nil)
    }
    
}
