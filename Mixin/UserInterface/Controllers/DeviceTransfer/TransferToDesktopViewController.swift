import UIKit
import Combine
import MixinServices

class TransferToDesktopViewController: DeviceTransferSettingViewController {
    
    private var stateObserver: AnyCancellable?
    private var server: DeviceTransferServer!
    
    private lazy var dataSource = SettingsDataSource(sections: [section])
    
    private let section = SettingsRadioSection(rows: [SettingsRow(title: R.string.localizable.transfer_now(), titleStyle: .highlighted)])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableHeaderView.imageView.image = R.image.setting.ic_transfer_desktop()
        tableHeaderView.label.text = R.string.localizable.transfer_to_pc_hint()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
    class func instance() -> UIViewController {
        let vc = TransferToDesktopViewController()
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.transfer_to_pc())
    }
    
}

extension TransferToDesktopViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if AppGroupUserDefaults.Account.isDesktopLoggedIn {
            guard ReachabilityManger.shared.isReachableOnEthernetOrWiFi else {
                alert(R.string.localizable.devices_on_same_network())
                return
            }
            tableView.isUserInteractionEnabled = false
            let section = SettingsRadioSection(footer: R.string.localizable.open_desktop_to_confirm(),
                                               rows: [SettingsRow(title: R.string.localizable.waiting(), titleStyle: .normal)])
            section.setAccessory(.busy, forRowAt: indexPath.row)
            dataSource.replaceSection(at: indexPath.section, with: section, animation: .automatic)
            sendPushCommand()
        } else {
            alert(R.string.localizable.login_desktop_first())
        }
    }
    
}

extension TransferToDesktopViewController {
    
    private func sendPushCommand() {
        if let server = try? DeviceTransferServer(), let ip = NetworkInterface.firstEthernetHostname() {
            self.server = server
            stateObserver = server.$displayState
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: stateDidChange(_:))
            server.start()
            let pushCommand = DeviceTransferCommand(action: .push, ip: ip, port: Int(server.port), code: server.code)
            guard
                let jsonData = try? JSONEncoder.default.encode(pushCommand),
                let content = String(data: jsonData, encoding: .utf8),
                let sessionId = AppGroupUserDefaults.Account.extensionSession,
                let conversationId = ParticipantDAO.shared.joinedConversationId()
            else {
                alert(R.string.localizable.connection_establishment_failed(), message: nil) { _ in
                    self.navigationController?.popViewController(animated: true)
                }
                return
            }
            SendMessageService.shared.sendDeviceTransferCommand(content, conversationId: conversationId, sessionId: sessionId)
        } else {
            alert(R.string.localizable.connection_establishment_failed(), message: nil) { _ in
                self.navigationController?.popViewController(animated: true)
            }
            Logger.general.debug(category: "TransferToDesktopViewController", message: "Failed to launch server")
        }
    }
    
    private func stateDidChange(_ state: DeviceTransferDisplayState) {
        switch state {
        case .connected :
            stateObserver?.cancel()
            let controller = DeviceTransferProgressViewController()
            controller.invoker = .transferToDesktop(server)
            navigationController?.pushViewController(controller, animated: true)
        case let .failed(error):
            dataSource.replaceSection(at: 0, with: section, animation: .automatic)
            switch error {
            case .mismatchedUserId:
                alert(R.string.localizable.unable_synced_between_different_account(), message: nil)
            case .mismatchedCode:
                alert(R.string.localizable.connection_establishment_failed(), message: nil)
            case .exception, .completed:
                break
            }
        case .preparing, .ready, .transporting, .finished, .closed:
            break
        }
    }
    
}
