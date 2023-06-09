import UIKit
import MixinServices

class TransferToPhoneViewController: DeviceTransferSettingViewController {
    
    private lazy var conversationRangeRow = SettingsRow(title: R.string.localizable.conversations(),
                                                         subtitle: DeviceTransferRange.Conversation.all.title,
                                                         accessory: .disclosure)
    private lazy var dateRangeRow = SettingsRow(title: R.string.localizable.date(),
                                                subtitle: DeviceTransferRange.Date.all.title,
                                                accessory: .disclosure)
    
    private lazy var dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [SettingsRow(title: R.string.localizable.transfer_now(), titleStyle: .highlighted)]),
        SettingsRadioSection(rows: [conversationRangeRow, dateRangeRow])
    ])
    
    private var range = DeviceTransferRange(conversation: .all, date: .all)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableHeaderView.imageView.image = R.image.setting.ic_transfer_phone()
        tableHeaderView.label.text = R.string.localizable.transfer_hint()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
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
            controller = TransferToPhoneQRCodeViewController.instance(range: range)
        default:
            switch indexPath.row {
            case 0:
                controller = DeviceTransferConversationSelectionViewController.instance(range: range.conversation,
                                                                                        rangeChanged: updateCoversationRangeRow(conversationRange:))
            default:
                controller = DeviceTransferDateSelectionViewController.instance(range: range.date,
                                                                                rangeChanged: updateDateRangeRow(dateRange:))
            }
        }
        navigationController?.pushViewController(controller, animated: true)
    }
    
}

extension TransferToPhoneViewController {
    
    private func updateCoversationRangeRow(conversationRange: DeviceTransferRange.Conversation) {
        range.conversation = conversationRange
        conversationRangeRow.subtitle = conversationRange.title
    }
    
    private func updateDateRangeRow(dateRange: DeviceTransferRange.Date) {
        range.date = dateRange
        dateRangeRow.subtitle = dateRange.title
    }
    
}
