import UIKit
import MixinServices

class TransferToPhoneViewController: DeviceTransferSettingViewController {
    
    private lazy var dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [SettingsRow(title: R.string.localizable.transfer_now(), titleStyle: .highlighted)])
    ])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.transfer_to_another_phone()
        tableHeaderView.imageView.image = R.image.setting.ic_transfer_phone()
        tableHeaderView.label.text = R.string.localizable.transfer_hint()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
}

extension TransferToPhoneViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard ReachabilityManger.shared.isReachableOnEthernetOrWiFi else {
            Logger.general.info(category: "TransferToPhone", message: "Network is not reachable")
            alert(R.string.localizable.devices_on_same_network())
            return
        }
        let controller = TransferToPhoneQRCodeViewController()
        navigationController?.pushViewController(controller, animated: true)
    }
    
}
