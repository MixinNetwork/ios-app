import UIKit
import MixinServices

class TransferToPhoneViewController: DeviceTransferSettingViewController {
    
    private lazy var conversationFilterRow = SettingsRow(title: R.string.localizable.conversations(),
                                                         subtitle: DeviceTransferFilter.Conversation.all.title,
                                                         accessory: .disclosure)
    private lazy var dateFilterRow = SettingsRow(title: R.string.localizable.date(),
                                                subtitle: DeviceTransferFilter.Time.all.title,
                                                accessory: .disclosure)
    
    private lazy var dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [SettingsRow(title: R.string.localizable.transfer_now(), titleStyle: .highlighted)]),
        SettingsRadioSection(rows: [conversationFilterRow, dateFilterRow])
    ])
    
    private let filter: DeviceTransferFilter = .passthrough()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableHeaderView.imageView.image = R.image.setting.ic_transfer_phone()
        tableHeaderView.label.text = R.string.localizable.transfer_hint()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
        NotificationCenter.default.addObserver(self, selector: #selector(updateFilterRows), name: DeviceTransferFilter.filterDidChangeNotification, object: filter)
    }
    
    class func instance() -> UIViewController {
        let vc = TransferToPhoneViewController()
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.transfer_to_another_phone())
    }
    
}

extension TransferToPhoneViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let controller: UIViewController
        switch indexPath.section {
        case 0:
            guard ReachabilityManger.shared.isReachableOnEthernetOrWiFi else {
                Logger.general.info(category: "TransferToPhone", message: "Network is not reachable")
                alert(R.string.localizable.devices_on_same_network())
                return
            }
            controller = TransferToPhoneQRCodeViewController.instance(filter: filter)
        default:
            switch indexPath.row {
            case 0:
                controller = DeviceTransferConversationSelectionViewController.instance(filter: filter)
            default:
                controller = DeviceTransferDateSelectionViewController.instance(filter: filter)
            }
        }
        navigationController?.pushViewController(controller, animated: true)
    }
    
}

extension TransferToPhoneViewController {
    
    @objc private func updateFilterRows() {
        conversationFilterRow.subtitle = filter.conversation.title
        dateFilterRow.subtitle = filter.time.title
    }
    
}
