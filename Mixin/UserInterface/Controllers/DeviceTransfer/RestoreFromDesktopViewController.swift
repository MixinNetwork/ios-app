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
        NotificationCenter.default.addObserver(self, selector: #selector(deviceTransfer(_:)), name: ReceiveMessageService.deviceTransferNotification, object: nil)
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
                Logger.general.info(category: "RestoreFromDesktopViewController", message: "Network is not reachable")
                alert(R.string.localizable.devices_on_same_network())
                return
            }
            guard WebSocketService.shared.isRealConnected else {
                Logger.general.info(category: "RestoreFromDesktopViewController", message: "WebSocket is not connected")
                alert(R.string.localizable.unable_connect_to_desktop())
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
                    Logger.general.info(category: "RestoreFromDesktopViewController", message: "LocalNetwork is not authorized")
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
        let pullCommand = DeviceTransferCommand(action: .pull)
        guard
            let jsonData = try? JSONEncoder.default.encode(pullCommand),
            let content = String(data: jsonData, encoding: .utf8),
            let sessionId = AppGroupUserDefaults.Account.extensionSession
        else {
            Logger.general.info(category: "RestoreFromDesktopViewController", message: "Send pull command failed, sessionId:\(String(describing: AppGroupUserDefaults.Account.extensionSession)) command: \(pullCommand)")
            alert(R.string.localizable.connection_establishment_failed(), message: nil) { _ in
                self.navigationController?.popViewController(animated: true)
            }
            return
        }
        Logger.general.info(category: "RestoreFromDesktopViewController", message: "Start send pull command")
        let conversationId = ParticipantDAO.shared.randomSuccessConversationID() ?? ConversationDAO.shared.makeConversationId(userId: myUserId, ownerUserId: MixinBot.teamMixin.id)
        SendMessageService.shared.sendDeviceTransferCommand(content, conversationId: conversationId, sessionId: sessionId)
    }
    
    @objc private func deviceTransfer(_ notification: Notification) {
        guard
            let data = notification.userInfo?[ReceiveMessageService.UserInfoKey.command] as? Data,
            let command = try? JSONDecoder.default.decode(DeviceTransferCommand.self, from: data)
        else {
            Logger.general.info(category: "RestoreFromDesktopViewController", message: "Not valid command: \(String(describing: notification.userInfo))")
            return
        }
        Logger.general.info(category: "RestoreFromDesktopViewController", message: "Notification command: \(command)")
        if command.action == .cancel {
            dataSource.replaceSection(at: 0, with: section, animation: .automatic)
            tableView.isUserInteractionEnabled = true
        } else {
            guard
                command.action == .push,
                let ip = command.ip,
                let port = command.port,
                let code = command.code
            else {
                Logger.general.info(category: "RestoreFromDesktopViewController", message: "Not valid command")
                alert(R.string.localizable.connection_establishment_failed(), message: nil) { _ in
                    self.navigationController?.popViewController(animated: true)
                }
                return
            }
            client = DeviceTransferClient(host: ip, port: UInt16(port), code: code)
            stateObserver = client.$displayState
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: { [weak self] state in
                    self?.stateDidChange(state)
                })
            client.start()
        }
    }
    
    private func stateDidChange(_ state: DeviceTransferDisplayState) {
        switch state {
        case .connected:
            stateObserver?.cancel()
            dataSource.replaceSection(at: 0, with: section, animation: .automatic)
            tableView.isUserInteractionEnabled = true
            let controller = DeviceTransferProgressViewController(intent: .restoreFromDesktop(client))
            navigationController?.pushViewController(controller, animated: true)
        case .failed:
            dataSource.replaceSection(at: 0, with: section, animation: .automatic)
            tableView.isUserInteractionEnabled = true
            stateObserver?.cancel()
            client.stop()
        case .preparing, .ready, .transporting, .finished, .closed:
            break
        }
    }
    
}
