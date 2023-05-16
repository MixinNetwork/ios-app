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
        NotificationCenter.default.addObserver(self, selector: #selector(deviceTransfer(_:)), name: ReceiveMessageService.deviceTransferNotification, object: nil)
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
                Logger.general.info(category: "TransferToDesktopViewController", message: "Network is not reachable")
                alert(R.string.localizable.devices_on_same_network())
                return
            }
            guard WebSocketService.shared.isRealConnected else {
                Logger.general.info(category: "TransferToDesktopViewController", message: "WebSocket is not connected")
                alert(R.string.localizable.unable_connect_to_desktop())
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
                .sink(receiveValue: { [weak self] state in
                    self?.stateDidChange(state)
                })
            server.start()
            let pushCommand = DeviceTransferCommand(action: .push, ip: ip, port: Int(server.port), code: server.code, userId: myUserId)
            guard
                let jsonData = try? JSONEncoder.default.encode(pushCommand),
                let content = String(data: jsonData, encoding: .utf8),
                let sessionId = AppGroupUserDefaults.Account.extensionSession
            else {
                Logger.general.info(category: "TransferToDesktopViewController", message: "Send push command failed, sessionId:\(String(describing: AppGroupUserDefaults.Account.extensionSession)), PushCommand: \(pushCommand)")
                alert(R.string.localizable.connection_establishment_failed(), message: nil) { _ in
                    self.navigationController?.popViewController(animated: true)
                }
                return
            }
            let conversationId = ParticipantDAO.shared.randomSuccessConversationID() ?? ConversationDAO.shared.makeConversationId(userId: myUserId, ownerUserId: MixinBot.teamMixin.id)
            SendMessageService.shared.sendDeviceTransferCommand(content, conversationId: conversationId, sessionId: sessionId)
        } else {
            alert(R.string.localizable.connection_establishment_failed(), message: nil) { _ in
                self.navigationController?.popViewController(animated: true)
            }
            Logger.general.info(category: "TransferToDesktopViewController", message: "Failed to launch server")
        }
    }
    
    private func stateDidChange(_ state: DeviceTransferDisplayState) {
        switch state {
        case .connected :
            stateObserver?.cancel()
            tableView.isUserInteractionEnabled = true
            dataSource.replaceSection(at: 0, with: section, animation: .automatic)
            let controller = DeviceTransferProgressViewController(intent: .transferToDesktop(server))
            navigationController?.pushViewController(controller, animated: true)
        case let .failed(error):
            tableView.isUserInteractionEnabled = true
            dataSource.replaceSection(at: 0, with: section, animation: .automatic)
            switch error {
            case .mismatchedUserId:
                alert(R.string.localizable.unable_synced_between_different_account(), message: nil)
            case .mismatchedCode:
                alert(R.string.localizable.connection_establishment_failed(), message: nil)
            case .exception, .completed:
                break
            }
        case .preparing, .ready, .transporting, .finished, .closed, .importing:
            break
        }
    }
    
    @objc private func deviceTransfer(_ notification: Notification) {
        guard
            let data = notification.userInfo?[ReceiveMessageService.UserInfoKey.command] as? Data,
            let command = try? JSONDecoder.default.decode(DeviceTransferCommand.self, from: data),
            command.action == .cancel
        else {
            Logger.general.info(category: "TransferToDesktopViewController", message: "Not valid command: \(String(describing: notification.userInfo))")
            return
        }
        Logger.general.info(category: "TransferToDesktopViewController", message: "Command: \(command))")
        tableView.isUserInteractionEnabled = true
        dataSource.replaceSection(at: 0, with: section, animation: .automatic)
    }
    
}
