import Foundation
import Alamofire
import Starscream
import Gzip

public class WebSocketService {
    
    static let didConnectNotification = Notification.Name("one.mixin.messenger.ws.connect")
    static let didDisconnectNotification = Notification.Name("one.mixin.messenger.ws.disconnect")
    
    static let shared = WebSocketService()
    
    var isConnected: Bool {
        return status == .connected
    }
    
    private let queue = DispatchQueue(label: "one.mixin.messenger.queue.websocket")
    private let queueSpecificKey = DispatchSpecificKey<Void>()
    private let messageQueue = DispatchQueue(label: "one.mixin.messenger.queue.websocket.message")
    private let refreshOneTimePreKeyInterval: TimeInterval = 3600 * 2
    
    private var host: String?
    private var rechability: NetworkReachabilityManager?
    private var socket: WebSocket?
    private var heartbeat: HeartbeatService?
    
    private var status: Status = .disconnected
    private var networkWasRechableOnConnection = false
    private var lastConnectionDate: Date?
    private var messageHandlers = [String: IncomingMessageHandler]()
    private var needsJobRestoration = true
    private var httpUpgradeSigningDate: Date?
    private var httpUpgradeServerDate: Date?
    private var connectOnNetworkIsReachable = false
    
    private var isReachable: Bool {
        return rechability?.isReachable ?? false
    }
    
    init() {
        queue.setSpecific(key: queueSpecificKey, value: ())
    }
    
    func connect() {
        enqueueOperation {
            guard self.status == .disconnected else {
                return
            }
            self.status = .connecting
            self.prepareForConnection(host: MixinServer.webSocketHost)
            self.networkWasRechableOnConnection = self.isReachable
            self.lastConnectionDate = Date()
            let headers = MixinRequest.getHeaders(request: self.socket!.request)
            self.httpUpgradeSigningDate = Date()
            self.httpUpgradeServerDate = nil
            for (field, value) in headers {
                self.socket!.request.setValue(value, forHTTPHeaderField: field)
            }
            self.socket!.connect()
        }
    }
    
    func disconnect() {
        enqueueOperation {
            guard self.status == .connecting || self.status == .connected else {
                return
            }
            self.connectOnNetworkIsReachable = false
            self.heartbeat?.stop()
            self.socket?.disconnect(forceTimeout: nil, closeCode: CloseCode.exit)
            self.needsJobRestoration = false
            ConcurrentJobQueue.shared.cancelAllOperations()
            self.messageHandlers.removeAll()
            self.status = .disconnected
        }
    }
    
    func reconnectIfNeeded() {
        enqueueOperation {
            let shouldReconnect = self.isReachable
                && AccountAPI.shared.didLogin
                && self.status == .connected
                && !(self.socket?.isConnected ?? false)
            if shouldReconnect {
                self.reconnect(sendDisconnectToRemote: true)
            }
        }
    }
    
    func respondedMessage(for message: BlazeMessage) throws -> BlazeMessage? {
        return try messageQueue.sync {
            guard AccountAPI.shared.didLogin else {
                return nil
            }
            var response: BlazeMessage?
            var err = APIError.createTimeoutError()
            
            let semaphore = DispatchSemaphore(value: 0)
            try queue.sync {
                messageHandlers[message.id] = { (jobResult) in
                    switch jobResult {
                    case let .success(blazeMessage):
                        response = blazeMessage
                    case let .failure(error):
                        if error.code == 10002 {
                            if let param = message.params, let messageId = param.messageId, messageId != messageId.lowercased() {
                                MessageDAO.shared.deleteMessage(id: messageId)
                                JobDAO.shared.removeJob(jobId: message.id)
                            }
                        }
                        err = error
                    }
                    semaphore.signal()
                }
                if !send(message: message) {
                    _ = messageHandlers.removeValue(forKey: message.id)
                    throw err
                }
            }
            _ = semaphore.wait(timeout: .now() + .seconds(5))
            
            guard let blazeMessage = response else {
                throw err
            }
            return blazeMessage
        }
    }
    
}

extension WebSocketService: WebSocketDelegate {
    
    public func websocketDidConnect(socket: WebSocketClient) {
        guard status == .connecting else {
            return
        }
        guard let signingDate = httpUpgradeSigningDate, let serverDate = httpUpgradeServerDate else {
            return
        }
        if abs(serverDate.timeIntervalSince(signingDate)) > 300 {
            if -signingDate.timeIntervalSinceNow > 60 {
                reconnect(sendDisconnectToRemote: true)
            } else {
                AppGroupUserDefaults.Account.isClockSkewed = true
                disconnect()
                DispatchQueue.main.async {
                    AppDelegate.current.window.rootViewController = makeInitialViewController()
                }
            }
        } else {
            status = .connected
            NotificationCenter.default.postOnMain(name: WebSocketService.didConnectNotification, object: self)
            ReceiveMessageService.shared.processReceiveMessages()
            requestListPendingMessages()
            ConcurrentJobQueue.shared.resume()
            heartbeat?.start()
            
            if let date = AppGroupUserDefaults.Crypto.oneTimePrekeyRefreshDate, -date.timeIntervalSinceNow > refreshOneTimePreKeyInterval {
                ConcurrentJobQueue.shared.addJob(job: RefreshAssetsJob())
                ConcurrentJobQueue.shared.addJob(job: RefreshOneTimePreKeysJob())
            }
            AppGroupUserDefaults.Crypto.oneTimePrekeyRefreshDate = Date()
            
            if rechability?.isReachableOnEthernetOrWiFi ?? false {
                if AppGroupUserDefaults.User.autoBackup != .off || AppGroupUserDefaults.Account.hasUnfinishedBackup {
                    BackupJobQueue.shared.addJob(job: BackupJob())
                }
                if AppGroupUserDefaults.Account.canRestoreMedia {
                    BackupJobQueue.shared.addJob(job: RestoreJob())
                }
            }
            ConcurrentJobQueue.shared.addJob(job: RefreshOffsetJob())
        }
    }
    
    public func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        if let error = error, NetworkManager.shared.isReachable {
            Reporter.report(error: error)
            if let error = error as? WSError, error.type == .writeTimeoutError {
                MixinServer.toggle(currentWebSocketHost: host)
            }
        }
        if status == .connecting || status == .connected {
            reconnect(sendDisconnectToRemote: false)
        }
    }
    
    public func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        
    }
    
    public func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        guard status == .connected else {
            return
        }
        guard data.isGzipped, let unzipped = try? data.gunzipped() else {
            return
        }
        guard let message = try? JSONDecoder.default.decode(BlazeMessage.self, from: unzipped) else {
            return
        }
        if let error = message.error {
            if let handler = messageHandlers[message.id] {
                messageHandlers.removeValue(forKey: message.id)
                handler(.failure(error))
            }
            let needsLogout = message.action == BlazeMessageAction.error.rawValue
                && error.code == 401
                && !AppGroupUserDefaults.Account.isClockSkewed
            if needsLogout {
                AccountAPI.shared.logout(from: "WebSocketService")
            }
        } else {
            if let handler = messageHandlers[message.id] {
                messageHandlers.removeValue(forKey: message.id)
                handler(.success(message))
            }
            if message.data != nil {
                if message.isReceiveMessageAction() {
                    ReceiveMessageService.shared.receiveMessage(blazeMessage: message)
                } else {
                    guard let data = message.toBlazeMessageData() else {
                        return
                    }
                    SendMessageService.shared.sendAckMessage(messageId: data.messageId, status: .READ)
                }
            }
        }
    }
    
}

extension WebSocketService {
    
    private enum Status {
        case disconnected
        case connecting
        case connected
    }
    
    private enum CloseCode {
        static let exit: UInt16 = 9999
        static let failure: UInt16 = 9998
    }
    
    private typealias IncomingMessageHandler = (APIResult<BlazeMessage>) -> Void
    
    private func enqueueOperation(_ closure: @escaping () -> Void) {
        if DispatchQueue.getSpecific(key: queueSpecificKey) == nil {
            queue.async(execute: closure)
        } else {
            closure()
        }
    }
    
    private func prepareForConnection(host: String) {
        let url: URL = URL(string: "wss://" + host)!
        guard socket?.currentURL != url else {
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        let socket = WebSocket(request: request)
        socket.delegate = self
        socket.callbackQueue = queue
        socket.onHttpResponseHeaders = { [weak self] headers in
            // This is called from an arbitrary queue instead of designated callback queue
            // Probably a bug of Starscream
            self?.updateHttpUpgradeServerDate(headers: headers)
        }
        self.socket = socket
        
        let heartbeat = HeartbeatService(socket: socket)
        heartbeat.onOffline = { [weak self] in
            self?.reconnect(sendDisconnectToRemote: true)
        }
        self.heartbeat = heartbeat
        
        rechability?.stopListening()
        rechability = NetworkReachabilityManager(host: host)
        rechability?.listener = { [weak self] status in
            guard case .reachable(_) = status else {
                return
            }
            self?.networkBecomesReachable()
        }
        rechability?.startListening()
    }
    
    private func updateHttpUpgradeServerDate(headers: HTTPHeaders) {
        enqueueOperation {
            guard let xServerTime = headers["x-server-time"], let time = Double(xServerTime) else {
                return
            }
            self.httpUpgradeServerDate = Date(timeIntervalSince1970: time / 1000000000)
        }
    }
    
    private func networkBecomesReachable() {
        enqueueOperation {
            guard self.connectOnNetworkIsReachable, AccountAPI.shared.didLogin else {
                return
            }
            self.connect()
        }
    }
    
    private func reconnect(sendDisconnectToRemote: Bool) {
        enqueueOperation {
            ReceiveMessageService.shared.refreshRefreshOneTimePreKeys = [String: TimeInterval]()
            for handler in self.messageHandlers.values {
                handler(.failure(APIError.createTimeoutError()))
            }
            self.messageHandlers.removeAll()
            ConcurrentJobQueue.shared.suspend()
            self.heartbeat?.stop()
            if sendDisconnectToRemote {
                self.socket?.disconnect(forceTimeout: nil, closeCode: CloseCode.failure)
            }
            self.status = .disconnected
            NotificationCenter.default.postOnMain(name: WebSocketService.didDisconnectNotification, object: self)
            
            let lastConnectionDate = self.lastConnectionDate ?? .distantPast
            let shouldConnectImmediately = self.isReachable
                && AccountAPI.shared.didLogin
                && (!self.networkWasRechableOnConnection || -lastConnectionDate.timeIntervalSinceNow >= 1)
            if shouldConnectImmediately {
                self.connectOnNetworkIsReachable = false
                self.connect()
            } else {
                self.status = .disconnected
                self.connectOnNetworkIsReachable = true
            }
        }
    }
    
    @discardableResult
    private func send(message: BlazeMessage) -> Bool {
        guard let socket = socket, status == .connected else {
            return false
        }
        guard let data = try? JSONEncoder.default.encode(message), let gzipped = try? data.gzipped() else {
            return false
        }
        socket.write(data: gzipped)
        return true
    }
    
    private func requestListPendingMessages() {
        let message = BlazeMessage(action: BlazeMessageAction.listPendingMessages.rawValue)
        messageHandlers[message.id] = { (result) in
            switch result {
            case .success:
                if self.needsJobRestoration {
                    self.needsJobRestoration = false
                    SendMessageService.shared.restoreJobs()
                    ConcurrentJobQueue.shared.restoreJobs()
                }
            case .failure:
                self.queue.asyncAfter(deadline: .now() + 2, execute: {
                    guard let socket = self.socket, socket.isConnected else {
                        return
                    }
                    self.requestListPendingMessages()
                })
            }
        }
        send(message: message)
    }
    
}
