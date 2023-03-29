import UIKit

class TransferToPhoneViewController: DeviceTransferSettingViewController {
    
    private lazy var dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [SettingsRow(title: R.string.localizable.transfer_now(), titleStyle: .highlighted)])
    ])
    
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
        let controller = TransferToPhoneQRCodeViewController.instance()
        navigationController?.pushViewController(controller, animated: true)
    }
    
}
