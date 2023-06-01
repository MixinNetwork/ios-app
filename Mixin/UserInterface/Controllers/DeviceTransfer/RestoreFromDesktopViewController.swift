import UIKit
import Combine
import MixinServices

class RestoreFromDesktopViewController: DeviceTransferSettingViewController {
    
    private let authorization = LocalNetworkAuthorization()
    private let section = SettingsRadioSection(rows: [
        SettingsRow(title: R.string.localizable.restore_now(), titleStyle: .highlighted)
    ])
    
    private lazy var dataSource = SettingsDataSource(sections: [section])
    
    private var stateObserver: AnyCancellable?
    
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
                Logger.general.info(category: "RestoreFromDesktop", message: "Network is not reachable")
                alert(R.string.localizable.devices_on_same_network())
                return
            }
            guard WebSocketService.shared.isRealConnected else {
                Logger.general.info(category: "RestoreFromDesktop", message: "WebSocket is not connected")
                alert(R.string.localizable.unable_connect_to_desktop())
                return
            }
            let section = SettingsRadioSection(footer: R.string.localizable.open_desktop_to_confirm(),
                                               rows: [SettingsRow(title: R.string.localizable.waiting(), titleStyle: .normal)])
            section.setAccessory(.busy, forRowAt: indexPath.row)
            dataSource.replaceSection(at: indexPath.section, with: section, animation: .automatic)
            tableView.isUserInteractionEnabled = false
            authorization.requestAuthorization { [weak self] isAuthorized in
                guard let strongSelf = self else {
                    return
                }
                if isAuthorized {
                    strongSelf.sendPullCommand() { success in
                        if !success, let self {
                            self.alert(R.string.localizable.unable_connect_to_desktop())
                            self.dataSource.replaceSection(at: 0, with: self.section, animation: .automatic)
                            self.tableView.isUserInteractionEnabled = true
                        }
                    }
                } else {
                    tableView.isUserInteractionEnabled = true
                    strongSelf.dataSource.replaceSection(at: 0, with: strongSelf.section, animation: .automatic)
                    Logger.general.info(category: "RestoreFromDesktop", message: "LocalNetwork is not authorized")
                    strongSelf.alertSettings(R.string.localizable.local_network_unable_accessed())
                }
            }
        } else {
            alert(R.string.localizable.login_desktop_first())
        }
    }
    
}

extension RestoreFromDesktopViewController {
    
    private func sendPullCommand(completion: @escaping (Bool) -> Void) {
        let pull = DeviceTransferCommand(action: .pull)
        guard
            let jsonData = try? JSONEncoder.default.encode(pull),
            let content = String(data: jsonData, encoding: .utf8),
            let sessionId = AppGroupUserDefaults.Account.extensionSession
        else {
            Logger.general.info(category: "RestoreFromDesktop", message: "Send pull command failed, sessionId:\(String(describing: AppGroupUserDefaults.Account.extensionSession)) command: \(pull)")
            alert(R.string.localizable.connection_establishment_failed(), message: nil) { _ in
                self.navigationController?.popViewController(animated: true)
            }
            return
        }
        Logger.general.info(category: "RestoreFromDesktop", message: "Start send pull command")
        let conversationId = ParticipantDAO.shared.randomSuccessConversationID()
            ?? ConversationDAO.shared.makeConversationId(userId: myUserId, ownerUserId: MixinBot.teamMixin.id)
        SendMessageService.shared.sendDeviceTransferCommand(content, conversationId: conversationId, sessionId: sessionId) { success in
            Logger.general.info(category: "RestoreFromDesktopViewController", message: "Send Pull command: \(success)")
            completion(success)
        }
    }
    
    @objc private func deviceTransfer(_ notification: Notification) {
        guard let data = notification.userInfo?[ReceiveMessageService.UserInfoKey.command] as? Data else {
            assertionFailure()
            return
        }
        
        let command: DeviceTransferCommand
        do {
            command = try JSONDecoder.default.decode(DeviceTransferCommand.self, from: data)
        } catch {
            Logger.general.info(category: "RestoreFromDesktop", message: "Unable to decode notification: \(error)")
            return
        }
        
        Logger.general.info(category: "RestoreFromDesktop", message: "Notification command: \(command)")
        switch command.action {
        case .cancel:
            dataSource.replaceSection(at: 0, with: section, animation: .automatic)
            tableView.isUserInteractionEnabled = true
        case let .push(context):
            let client = DeviceTransferClient(hostname: context.hostname,
                                              port: context.port,
                                              code: context.code,
                                              key: context.key,
                                              remotePlatform: command.platform)
            stateObserver = client.$state
                .receive(on: DispatchQueue.main)
                .sink { [weak self] state in
                    self?.stateDidChange(client: client, state: state)
                }
            client.start()
        default:
            Logger.general.info(category: "RestoreFromDesktop", message: "Invalid command")
            alert(R.string.localizable.connection_establishment_failed(), message: nil) { _ in
                self.navigationController?.popViewController(animated: true)
            }
        }
    }
    
    private func stateDidChange(client: DeviceTransferClient, state: DeviceTransferClient.State) {
        switch state {
        case .idle, .importing:
            break
        case .transfer:
            stateObserver?.cancel()
            dataSource.replaceSection(at: 0, with: section, animation: .automatic)
            tableView.isUserInteractionEnabled = true
            let progress = DeviceTransferProgressViewController(connection: .client(client, .desktop))
            navigationController?.pushViewController(progress, animated: true)
        case let .closed(reason):
            dataSource.replaceSection(at: 0, with: section, animation: .automatic)
            tableView.isUserInteractionEnabled = true
            stateObserver?.cancel()
            if case let .exception(error) = reason {
                alert(R.string.localizable.connection_establishment_failed(), message: error.localizedDescription) { _ in
                    self.navigationController?.popViewController(animated: true)
                }
            }
        }
    }
    
}
