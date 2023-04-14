import UIKit
import Combine
import MixinServices

class RestoreFromDesktopViewController: DeviceTransferSettingViewController {
    
    private var stateObserver: AnyCancellable?
    private var client: DeviceTransferClient!
    
    private let section = SettingsRadioSection(rows: [SettingsRow(title: R.string.localizable.restore_now(), titleStyle: .highlighted)])
    
    private lazy var dataSource = SettingsDataSource(sections: [section])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableHeaderView.imageView.image = R.image.setting.ic_restore_desktop()
        tableHeaderView.label.text = R.string.localizable.restore_from_pc_tip()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
    class func instance() -> UIViewController {
        let vc = RestoreFromDesktopViewController()
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.restore_from_pc())
    }
    
}

extension RestoreFromDesktopViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if AppGroupUserDefaults.Account.isDesktopLoggedIn {
            guard ReachabilityManger.shared.isReachableOnEthernetOrWiFi else {
                alert(R.string.localizable.devices_on_same_network())
                return
            }
            LocalNetwork.requestAuthorization { isAuthorized in
                if isAuthorized {
                    tableView.isUserInteractionEnabled = false
                    let section = SettingsRadioSection(footer: R.string.localizable.open_desktop_to_confirm(),
                                                       rows: [SettingsRow(title: R.string.localizable.waiting(), titleStyle: .normal)])
                    section.setAccessory(.busy, forRowAt: indexPath.row)
                    self.dataSource.replaceSection(at: indexPath.section, with: section, animation: .automatic)
                    self.sendPullCommand()
                } else {
                    self.alertSettings(R.string.localizable.local_network_unable_accessed())
                }
            }
        } else {
            alert(R.string.localizable.login_desktop_first())
        }
    }
    
}

extension RestoreFromDesktopViewController {
    
    private func sendPullCommand() {
        NotificationCenter.default.addObserver(self, selector: #selector(deviceTransfer(_:)), name: ReceiveMessageService.deviceTransferNotification, object: nil)
        let pullCommand = DeviceTransferCommand(action: .pull)
        guard
            let jsonData = try? JSONEncoder.default.encode(pullCommand),
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
    }
    
    @objc private func deviceTransfer(_ notification: Notification) {
        guard
            let data = notification.userInfo?[ReceiveMessageService.UserInfoKey.command] as? Data,
            let command = try? JSONDecoder.default.decode(DeviceTransferCommand.self, from: data),
            command.action == .push,
            let ip = command.ip,
            let port = command.port,
            let code = command.code
        else {
            alert(R.string.localizable.connection_establishment_failed(), message: nil) { _ in
                self.navigationController?.popViewController(animated: true)
            }
            return
        }
        client = DeviceTransferClient(host: ip, port: UInt16(port), code: code)
        stateObserver = client.$displayState
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: stateDidChange(_:))
        client.start()
    }
    
    private func stateDidChange(_ state: DeviceTransferDisplayState) {
        switch state {
        case .connected:
            stateObserver?.cancel()
            let controller = DeviceTransferProgressViewController()
            controller.invoker = .restoreFromDesktop(client)
            navigationController?.pushViewController(withBackChat: controller)
        case .failed:
            tableView.isUserInteractionEnabled = true
            stateObserver?.cancel()
            client.stop()
        case .preparing, .ready, .transporting, .finished, .closed:
            break
        }
    }
    
}
