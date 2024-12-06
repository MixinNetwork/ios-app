import UIKit

class AboutViewController: SettingsTableViewController {
    
    @IBOutlet weak var versionLabel: UILabel!
    
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.follow_us_on_x(), accessory: .disclosure),
            SettingsRow(title: R.string.localizable.follow_us_on_facebook(), accessory: .disclosure),
            SettingsRow(title: R.string.localizable.help_center(), accessory: .disclosure),
            SettingsRow(title: R.string.localizable.terms_of_service(), accessory: .disclosure),
            SettingsRow(title: R.string.localizable.privacy_policy(), accessory: .disclosure),
            SettingsRow(title: R.string.localizable.acknowledgements(), accessory: .disclosure),
            SettingsRow(title: R.string.localizable.version_update(), accessory: .disclosure)
        ])
    ])
    
    private lazy var diagnoseRow = SettingsRow(title: R.string.localizable.diagnose(), accessory: .disclosure)
    
    private var isShowingDiagnoseRow = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableHeaderView = R.nib.aboutTableHeaderView(withOwner: self)
        versionLabel.text = Bundle.main.fullVersion
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
        #if DEBUG
        showDiagnoseRow(self)
        #endif
    }
    
    @IBAction func showDiagnoseRow(_ sender: Any) {
        guard !isShowingDiagnoseRow else {
            return
        }
        dataSource.appendRows([diagnoseRow], into: 0, animation: .automatic)
        isShowingDiagnoseRow = true
    }
    
}

extension AboutViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.row {
        case 0:
            UIApplication.shared.openURL(url: "https://x.com/intent/follow?screen_name=MixinMessenger")
        case 1:
            UIApplication.shared.openURL(url: "https://fb.com/MixinMessenger")
        case 2:
            UIApplication.shared.openURL(url: "https://mixinmessenger.zendesk.com")
        case 3:
            UIApplication.shared.openURL(url: .terms)
        case 4:
            UIApplication.shared.openURL(url: .privacy)
        case 5:
            let acknow = AcknowledgementListViewController()
            navigationController?.pushViewController(acknow, animated: true)
        case 6:
            UIApplication.shared.openAppStorePage()
        case 7:
            let diagnose = DiagnoseViewController()
            navigationController?.pushViewController(diagnose, animated: true)
        default:
            break
        }
    }
    
}
