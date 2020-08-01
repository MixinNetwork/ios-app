import UIKit
import MixinServices

class PhoneNumberSettingViewController: SettingsTableViewController {
    
    private let section = SettingsRadioSection(header: R.string.localizable.setting_header_search_source(), rows: [
        SettingsRow(title: R.string.localizable.setting_source_everybody()),
        SettingsRow(title: R.string.localizable.setting_source_contacts()),
        SettingsRow(title: R.string.localizable.setting_source_nobody())
    ])
    
    private lazy var dataSource = SettingsDataSource(sections: [section])
    
    private var currentSelectedRowIndex: Int {
        guard let account = LoginManager.shared.account else {
            return 0
        }
        switch account.accept_search_source {
        case AcceptSearchSource.everybody.rawValue:
            return 0
        case AcceptSearchSource.contacts.rawValue:
            return 1
        case AcceptSearchSource.nobody.rawValue:
            return 2
        default:
            return 0
        }
    }
    
    class func instance() -> UIViewController {
        let vc = PhoneNumberSettingViewController()
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.setting_phone_number_title())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        section.setAccessory(.checkmark, forRowAt: currentSelectedRowIndex)
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
}

extension PhoneNumberSettingViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let newSource: AcceptSearchSource
        switch indexPath.row {
        case 0:
            newSource = .everybody
        case 1:
            newSource = .contacts
        default:
            newSource = .nobody
        }
        
        guard newSource.rawValue != LoginManager.shared.account?.accept_search_source else {
            return
        }
        let indexBefore = self.currentSelectedRowIndex
        tableView.isUserInteractionEnabled = false
        section.setAccessory(.busy, forRowAt: indexPath.row)
        let request = UserPreferenceRequest(accept_search_source: newSource.rawValue)
        AccountAPI.preferences(preferenceRequest: request, completion: { [weak self] (result) in
            guard let self = self else {
                return
            }
            self.tableView.isUserInteractionEnabled = true
            switch result {
            case .success(let account):
                self.section.setAccessory(.checkmark, forRowAt: indexPath.row)
                LoginManager.shared.setAccount(account)
            case let .failure(error):
                self.section.setAccessory(.checkmark, forRowAt: indexBefore)
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        })
    }
    
}
