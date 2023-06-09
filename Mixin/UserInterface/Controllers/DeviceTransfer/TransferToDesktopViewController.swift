import UIKit
import Combine
import MixinServices

class TransferToDesktopViewController: DeviceTransferSettingViewController {
    
    private lazy var actionSection = SettingsRadioSection(rows: [
        SettingsRow(title: R.string.localizable.transfer_now(), titleStyle: .highlighted),
    ])
    private lazy var conversationRangeRow = SettingsRow(title: R.string.localizable.conversations(),
                                                         subtitle: DeviceTransferRange.Conversation.all.title,
                                                         accessory: .disclosure)
    private lazy var dateRangeRow = SettingsRow(title: R.string.localizable.date(),
                                                subtitle: DeviceTransferRange.Date.all.title,
                                                accessory: .disclosure)
    private lazy var dataSource = SettingsDataSource(sections: [
        actionSection,
        SettingsRadioSection(rows: [conversationRangeRow, dateRangeRow])
    ])
    
    private var range = DeviceTransferRange(conversation: .all, date: .all)
    private var observers: Set<AnyCancellable> = []
    private var server: DeviceTransferServer?
    
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
        switch indexPath.section {
        case 0:
            prepareTransfer()
        default:
            let controller: UIViewController
            switch indexPath.row {
            case 0:
                controller = DeviceTransferConversationSelectionViewController.instance(range: range.conversation,
                                                                                        rangeChanged: updateCoversationRangeRow(conversationRange:))
            default:
                controller = DeviceTransferDateSelectionViewController.instance(range: range.date,
                                                                                rangeChanged: updateDateRangeRow(dateRange:))
            }
            navigationController?.pushViewController(controller, animated: true)
        }
    }
    
}

// MARK: - State Handler
extension TransferToDesktopViewController {
    
    @objc private func deviceTransfer(_ notification: Notification) {
        guard
            let data = notification.userInfo?[ReceiveMessageService.UserInfoKey.command] as? Data,
            let command = try? JSONDecoder.default.decode(DeviceTransferCommand.self, from: data),
            case .cancel = command.action
        else {
            Logger.general.info(category: "TransferToDesktop", message: "Invalid command: \(String(describing: notification.userInfo))")
            return
        }
        Logger.general.info(category: "TransferToDesktop", message: "Command: \(command))")
        tableView.isUserInteractionEnabled = true
        dataSource.replaceSection(at: 0, with: actionSection, animation: .automatic)
        server?.stopListening()
    }
    
    private func server(_ server: DeviceTransferServer, didChangeToState state: DeviceTransferServer.State) {
        switch state {
        case .idle:
            break
        case let .listening(hostname, port):
            let context = DeviceTransferCommand.PushContext(hostname: hostname,
                                                            port: port,
                                                            code: server.code,
                                                            key: server.key,
                                                            userID: myUserId)
            let push = DeviceTransferCommand(action: .push(context))
            guard
                let jsonData = try? JSONEncoder.default.encode(push),
                let content = String(data: jsonData, encoding: .utf8),
                let sessionId = AppGroupUserDefaults.Account.extensionSession
            else {
                Logger.general.info(category: "TransferToDesktop", message: "Send push command failed, sessionId:\(String(describing: AppGroupUserDefaults.Account.extensionSession)), PushCommand: \(push)")
                alert(R.string.localizable.connection_establishment_failed(), message: nil) { _ in
                    self.navigationController?.popViewController(animated: true)
                }
                Logger.general.error(category: "TransferToDesktop", message: "Unable to make push command")
                return
            }
            let conversationId = ParticipantDAO.shared.randomSuccessConversationID()
                ?? ConversationDAO.shared.makeConversationId(userId: myUserId, ownerUserId: MixinBot.teamMixin.id)
            SendMessageService.shared.sendDeviceTransferCommand(content, conversationId: conversationId, sessionId: sessionId) { [weak self] success in
                Logger.general.info(category: "TransferToDesktop", message: "Send push command: \(success)")
                if !success, let self {
                    self.alert(R.string.localizable.unable_connect_to_desktop())
                    self.dataSource.replaceSection(at: 0, with: self.actionSection, animation: .automatic)
                    self.tableView.isUserInteractionEnabled = true
                }
            }
        case .transfer:
            observers.forEach({ $0.cancel() })
            tableView.isUserInteractionEnabled = true
            dataSource.replaceSection(at: 0, with: actionSection, animation: .automatic)
            let progress = DeviceTransferProgressViewController(connection: .server(server, .desktop))
            navigationController?.pushViewController(progress, animated: true)
        case let .closed(reason):
            switch reason {
            case .finished:
                break
            case .exception(let error):
                alert(R.string.localizable.connection_establishment_failed(), message: error.localizedDescription) { _ in
                    self.navigationController?.popViewController(animated: true)
                }
            }
        }
    }
    
    private func server(_ server: DeviceTransferServer, didRejectConnection reason: DeviceTransferServer.ConnectionRejectedReason) {
        tableView.isUserInteractionEnabled = true
        dataSource.replaceSection(at: 0, with: actionSection, animation: .automatic)
        let title: String
        switch reason {
        case .mismatchedUser:
            title = R.string.localizable.unable_synced_between_different_account()
        case .mismatchedCode:
            title = R.string.localizable.connection_establishment_failed()
        }
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: R.string.localizable.ok(), style: .cancel) { [server] _ in
            server.consumeLastConnectionBlockedReason()
        })
        present(alert, animated: true, completion: nil)
    }
    
}

extension TransferToDesktopViewController {
    
    private func prepareTransfer() {
        if AppGroupUserDefaults.Account.isDesktopLoggedIn {
            guard ReachabilityManger.shared.isReachableOnEthernetOrWiFi else {
                Logger.general.info(category: "TransferToDesktop", message: "Network is not reachable")
                alert(R.string.localizable.devices_on_same_network())
                return
            }
            guard WebSocketService.shared.isRealConnected else {
                Logger.general.info(category: "TransferToDesktop", message: "WebSocket is not connected")
                alert(R.string.localizable.unable_connect_to_desktop())
                return
            }
            tableView.isUserInteractionEnabled = false
            let section = SettingsRadioSection(footer: R.string.localizable.open_desktop_to_confirm(),
                                               rows: [SettingsRow(title: R.string.localizable.waiting(), titleStyle: .normal)])
            section.setAccessory(.busy, forRowAt: 0)
            dataSource.replaceSection(at: 0, with: section, animation: .automatic)
            let server = DeviceTransferServer()
            server.$state
                .receive(on: DispatchQueue.main)
                .sink { [weak self] state in
                    self?.server(server, didChangeToState: state)
                }
                .store(in: &observers)
            server.$lastConnectionRejectedReason
                .sink { [weak self] reason in
                    if let self, let reason {
                        self.server(server, didRejectConnection: reason)
                    }
                }
                .store(in: &observers)
            self.server = server
            server.startListening() { [weak self] error in
                guard let self else {
                    return
                }
                Logger.general.info(category: "TransferToDesktop", message: "Failed to start listening: \(error)")
                self.alert(R.string.localizable.connection_establishment_failed()) { _ in
                    self.navigationController?.popViewController(animated: true)
                }
            }
        } else {
            alert(R.string.localizable.login_desktop_first())
        }
    }
    
    private func updateCoversationRangeRow(conversationRange: DeviceTransferRange.Conversation) {
        range.conversation = conversationRange
        conversationRangeRow.subtitle = conversationRange.title
    }
    
    private func updateDateRangeRow(dateRange: DeviceTransferRange.Date) {
        range.date = dateRange
        dateRangeRow.subtitle = dateRange.title
    }
    
}
