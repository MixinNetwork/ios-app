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
                                               subtitle: R.string.localizable.current_language(),
                                               accessory: .disclosure)
    private let chatBackgroundRow = SettingsRow(title: R.string.localizable.chat_background(), accessory: .disclosure)
    private let chatTextSizeRow = SettingsRow(title: R.string.localizable.chat_text_size(), subtitle: chatTextSizeSubtitle, accessory: .disclosure)
    
    private class var chatTextSizeSubtitle: String {
        if AppGroupUserDefaults.User.useSystemFont {
            return R.string.localizable.system()
        } else {
            return "\(AppGroupUserDefaults.User.chatFontSize.fontSize)pt"
        }
    }
    
    private lazy var dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [currencyRow]),
        SettingsSection(rows: [chatBackgroundRow, chatTextSizeRow])
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
            if isLanguageAvailable {
                pickCurrency()
            } else {
                if indexPath.row == 0 {
                    changeChatBackground()
                } else {
                    changeChatTextSize()
                }
            }
        case 3:
            if indexPath.row == 0 {
                changeChatBackground()
            } else {
                changeChatTextSize()
            }
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
    
    @objc private func updatechatTextSizeSubtitle() {
        chatTextSizeRow.subtitle = Self.chatTextSizeSubtitle
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
        var currencies = Currency.all
        if let index = currencies.firstIndex(where: { $0.code == Currency.current.code }) {
            let selected = currencies.remove(at: index)
            currencies.insert(selected, at: 0)
        }
        let selector = CurrencySelectorViewController(currencies: currencies, selectedCurrencyCode: Currency.current.code) { currency in
            let hud = Hud()
            hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
            AccountAPI.preferences(preferenceRequest: UserPreferenceRequest(fiat_currency: currency.code), completion: { [weak self] (result) in
                switch result {
                case .success(let account):
                    LoginManager.shared.setAccount(account)
                    Currency.refreshCurrentCurrency()
                    hud.set(style: .notification, text: R.string.localizable.saved())
                    self?.dismiss(animated: true, completion: nil)
                case let .failure(error):
                    hud.set(style: .error, text: error.localizedDescription)
                }
                hud.scheduleAutoHidden()
            })
        }
        present(selector, animated: true, completion: nil)
    }
    
    private func changeChatBackground() {
        let vc = PreviewWallpaperViewController.instance(scope: .global)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func changeChatTextSize() {
        let vc = ChatTextSizeViewController.instance(fontSizeDidChange: updatechatTextSizeSubtitle)
        navigationController?.pushViewController(vc, animated: true)
    }
    
}
