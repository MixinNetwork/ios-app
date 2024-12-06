import UIKit
import MixinServices

class AppearanceSettingsViewController: SettingsTableViewController {
    
    private let currencyRow = SettingsRow(title: R.string.localizable.currency(), accessory: .disclosure)
    
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
        SettingsSection(rows: [userInterfaceStyleRow]),
        SettingsSection(rows: [languageRow]),
        SettingsSection(rows: [currencyRow]),
        SettingsSection(rows: [chatBackgroundRow, chatTextSizeRow]),
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.quote_color(),
                        subtitle: AppGroupUserDefaults.User.marketColorAppearance.description,
                        accessory: .disclosure,
                        menu: UIMenu(children: colorAppearanceActions()))
        ]),
    ])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.appearance()
        updateCurrencySubtitle()
        updateUserInterfaceStyleSubtitle()
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
            pickLanguage()
        case 2:
            pickCurrency()
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
    
    private func colorAppearanceActions() -> [UIAction] {
        let selected = AppGroupUserDefaults.User.marketColorAppearance
        return MarketColorAppearance.allCases.map { appearance in
            UIAction(
                title: appearance.description,
                image: appearance.image,
                state: appearance == selected ? .on : .off,
                handler: { [weak self] _ in self?.setColorAppearance(appearance) }
            )
        }
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
    
    private func changeChatBackground() {
        let vc = PreviewWallpaperViewController.instance(scope: .global)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func changeChatTextSize() {
        let vc = ChatTextSizeViewController.instance(fontSizeDidChange: updatechatTextSizeSubtitle)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func setColorAppearance(_ appearance: MarketColorAppearance) {
        AppGroupUserDefaults.User.marketColorAppearance = appearance
        let menu = UIMenu(children: colorAppearanceActions())
        let row = SettingsRow(
            title: R.string.localizable.quote_color(),
            subtitle: AppGroupUserDefaults.User.marketColorAppearance.description,
            accessory: .disclosure,
            menu: menu
        )
        let section = SettingsSection(rows: [row])
        dataSource.replaceSection(at: 4, with: section, animation: .none)
    }
    
}

extension MarketColorAppearance {
    
    var description: String {
        switch self {
        case .greenUpRedDown:
            R.string.localizable.green_up_red_down()
        case .redUpGreenDown:
            R.string.localizable.red_up_green_down()
        }
    }
    
    var image: UIImage {
        switch self {
        case .greenUpRedDown:
            R.image.green_up()!
        case .redUpGreenDown:
            R.image.red_up()!
        }
    }
    
}
