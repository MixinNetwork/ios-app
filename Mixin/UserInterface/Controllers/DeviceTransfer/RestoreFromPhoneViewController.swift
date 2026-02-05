import UIKit
import MixinServices

class RestoreFromPhoneViewController: DeviceTransferSettingViewController {
    
    private let authorization = LocalNetworkAuthorization()
    
    private lazy var dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [SettingsRow(title: R.string.localizable.scan_to_restore(), titleStyle: .highlighted)])
    ])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.restore_from_another_phone()
        tableHeaderView.imageView.image = R.image.setting.ic_transfer_phone()
        tableHeaderView.label.attributedText = makeDescription()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
}

extension RestoreFromPhoneViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard ReachabilityManger.shared.isReachableOnEthernetOrWiFi else {
            Logger.general.info(category: "RestoreFromPhone", message: "Network is not reachable")
            alert(R.string.localizable.devices_on_same_network())
            return
        }
        tableView.isUserInteractionEnabled = false
        authorization.requestAuthorization { [weak self] isAuthorized in
            guard let self else {
                return
            }
            self.tableView.isUserInteractionEnabled = true
            if isAuthorized {
                let controller = QRCodeScannerViewController()
                self.navigationController?.pushViewController(controller, animated: true)
            } else {
                Logger.general.info(category: "RestoreFromPhone", message: "LocalNetwork is not authorized")
                self.alertSettings(R.string.localizable.local_network_unable_accessed())
            }
        }
    }
    
}

extension RestoreFromPhoneViewController {
    
    private func makeDescription() -> NSAttributedString {
        let indentation: CGFloat = 10
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.tabStops = [NSTextTab(textAlignment: .left, location: indentation)]
        paragraphStyle.defaultTabInterval = indentation
        paragraphStyle.lineSpacing = 2
        paragraphStyle.paragraphSpacing = 6
        paragraphStyle.headIndent = indentation
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.scaledFont(ofSize: 14, weight: .regular),
            .foregroundColor: R.color.text()!,
            .paragraphStyle: paragraphStyle
        ]
        let bulletAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.scaledFont(ofSize: 14, weight: .regular),
            .foregroundColor: R.color.text_tertiary()!
        ]
        let bullet = "• "
        let strings = [
            R.string.localizable.old_device_is_waiting(),
            R.string.localizable.scan_to_restore_hint(),
            R.string.localizable.keep_running_foreground()
        ]
        let bulletListString = NSMutableAttributedString()
        for string in strings {
            let formattedString: String
            if string == strings.last {
                formattedString = bullet + string
            } else {
                formattedString = bullet + string + "\n"
            }
            let attributedString = NSMutableAttributedString(string: formattedString, attributes: textAttributes)
            let rangeForBullet = NSString(string: formattedString).range(of: bullet)
            attributedString.addAttributes(bulletAttributes, range: rangeForBullet)
            bulletListString.append(attributedString)
        }
        return bulletListString
    }
    
}
