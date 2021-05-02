import Foundation
import Alamofire
import Gzip

public class WebSocketService {
    
    public static let didConnectNotification = Notification.Name("one.mixin.services.ws.connect")
    public static let didDisconnectNotification = Notification.Name("one.mixin.services.ws.disconnect")
    public static let didSendListPendingMessageNotification = Notification.Name("one.mixin.services.ws.pending")
    
    public static let shared = WebSocketService()
    
    public var isConnected: Bool {
        return status == .connected
    }

    public var isRealConnected: Bool {
        return socket?.isConnected ?? false
    }
    
    private let queue = Queue(label: "one.mixin.services.queue.websocket")
    private let messageQueue = DispatchQueue(label: "one.mixin.services.queue.websocket.message")
    
    private var host: String?
    private var socket: WebSocketProvider?
    private var heartbeat: HeartbeatService?
    
    private var status: Status = .disconnected
    private var messageHandlers = SafeDictionary<String, IncomingMessageHandler>()
    private var httpUpgradeSigningDate = Date()
    private var lastConnectionDate = Date()

    internal init() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(networkChanged),
                                               name: ReachabilityManger.reachabilityDidChangeNotification,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    public func connect(firstConnect: Bool = false) {
        queue.autoAsync {
            guard canProcessMessages else {
                return
            }
            guard ReachabilityManger.shared.isReachable else {
                NotificationCenter.default.post(onMainThread: WebSocketService.didDisconnectNotification, object: self)
                return
            }
            guard self.status == .disconnected else {
                return
            }
            guard let url = URL(string: "wss://\(MixinHost.webSocket)") else {
                return
            }

            if isAppExtension && AppGroupUserDefaults.isRunningInMainApp {
                return
            }

            if !firstConnect {
                NotificationCenter.default.post(onMainThread: WebSocketService.didDisconnectNotification, object: self)
            }

            self.host = MixinHost.webSocket
            self.status = .connecting

            let socket = RocketWebSocket(host: MixinHost.webSocket, queue: self.queue.dispatchQueue)
            self.socket = socket
            self.socket?.delegate = self

            let heartbeat = HeartbeatService(socket: socket)
            heartbeat.onOffline = { [weak self] in
                self?.reconnect(sendDisconnectToRemote: true)
            }
            self.heartbeat = heartbeat

            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            request.allHTTPHeaderFields = RequestSigning.signedHeaders(for: request)
            if isAppExtension {
                request.setValue("Mixin-Notification-Extension-1", forHTTPHeaderField: "Sec-WebSocket-Protocol")
            }

            self.lastConnectionDate = Date()
            self.httpUpgradeSigningDate = Date()
            self.socket?.serverTime = nil
            self.socket?.connect(request: request)
        }
    }
    
    public func disconnect() {
        queue.autoAsync {
            guard self.status == .connecting || self.status == .connected else {
                return
            }
            self.heartbeat?.stop()

            self.socket?.disconnect(closeCode: CloseCode.exit)
            ConcurrentJobQueue.shared.cancelAllOperations()
            self.messageHandlers.removeAll()
            self.status = .disconnected
        }
    }

    public func connectIfNeeded() {
        queue.autoAsync {
            guard canProcessMessages else {
                return
            }
            guard ReachabilityManger.shared.isReachable else {
                NotificationCenter.default.post(onMainThread: WebSocketService.didDisconnectNotification, object: self)
                return
            }
            if self.status == .connected && self.socket?.isConnected ?? false, let heartbeat = self.heartbeat {
                heartbeat.checkConnect()
            } else if self.status == .disconnected {
                self.connect()
            } else if self.status == .connected && !(self.socket?.isConnected ?? false) {
                self.reconnect(sendDisconnectToRemote: true)
            }
        }
    }
    
    internal func respondedMessage(for message: BlazeMessage) throws -> (success: Bool, blazeMessage: BlazeMessage?) {
        return try messageQueue.sync {
            guard LoginManager.shared.isLoggedIn else {
                return (false, nil)
            }
            var response: BlazeMessage?
            var err = MixinAPIError.webSocketTimeOut
            
            let semaphore = DispatchSemaphore(value: 0)
            messageHandlers[message.id] = { (jobResult) in
                switch jobResult {
                case let .success(blazeMessage):
                    response = blazeMessage
                case let .failure(error):
                    if case .invalidRequestData = error {
                        if let param = message.params, let messageId = param.messageId, messageId != messageId.lowercased() {
                            MessageDAO.shared.deleteMessage(id: messageId)
                            JobDAO.shared.removeJob(jobId: message.id)
                        }
                    }
                    if let conversationId = message.params?.conversationId {
                        Logger.write(conversationId: conversationId, log: "[WebSocketService][RespondedMessage][\(message.action)]...\(error)")
                    }
                    err = error
                }
                semaphore.signal()
            }

            let (success, isBadData) = send(message: message)
            if isBadData {
                messageHandlers.removeValue(forKey: message.id)
                return (true, nil)
            }
            if !success {
                messageHandlers.removeValue(forKey: message.id)
                throw err
            }
            
            if semaphore.wait(timeout: .now() + .seconds(Int(requestTimeout))) == .timedOut {
                let category = message.params?.category ?? ""
                let log = "[WebSocketService][RespondedMessage][\(category)]...semaphore timeout...requestTimeout:\(requestTimeout)"
                let conversationId = message.params?.conversationId ?? ""
                Logger.write(conversationId: conversationId, log: log)
            }
            
            guard let blazeMessage = response else {
                throw err
            }
            return (blazeMessage != nil, blazeMessage)
        }
    }
    
}

extension WebSocketService: WebSocketProviderDelegate {

    func websocketDidReceivePong(socket: WebSocketProvider) {
        queue.autoAsync {
            self.heartbeat?.websocketDidReceivePong()
        }
    }

    func websocketDidConnect(socket: WebSocketProvider) {
        guard status == .connecting else {
            return
        }

        if let responseServerTime = socket.serverTime, let serverTime = Double(responseServerTime), serverTime > 0 {
            let signingDate = httpUpgradeSigningDate
            let serverDate =  Date(timeIntervalSince1970: serverTime / 1000000000)
            if abs(serverDate.timeIntervalSince(signingDate)) > 300 {
                if -signingDate.timeIntervalSinceNow > 60 {
                    reconnect(sendDisconnectToRemote: true)
                } else {
                    AppGroupUserDefaults.Account.isClockSkewed = true
                    disconnect()
                    NotificationCenter.default.post(onMainThread: MixinService.clockSkewDetectedNotification, object: self)
                }
                return
            }
        }


        status = .connected
        NotificationCenter.default.post(onMainThread: WebSocketService.didConnectNotification, object: self)
        ReceiveMessageService.shared.processReceiveMessages()
        requestListPendingMessages()
        ConcurrentJobQueue.shared.resume()
        heartbeat?.start()
    }
    
    func websocketDidDisconnect(socket: WebSocketProvider, isSwitchNetwork: Bool) {
        guard status == .connecting || status == .connected else {
            return
        }

        if isSwitchNetwork {
            MixinHost.toggle(currentWebSocketHost: host)
        }

        reconnect(sendDisconnectToRemote: false)
    }

    func websocketDidReceiveData(socket: WebSocketProvider, data: Data) {
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
            if case .unauthorized = error, message.action == BlazeMessageAction.error.rawValue, !AppGroupUserDefaults.Account.isClockSkewed {
                LoginManager.shared.logout(from: "WebSocketService")
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
    
    public enum Status: String {
        case disconnected
        case connecting
        case connected
    }
    
    private typealias IncomingMessageHandler = (MixinAPI.Result<BlazeMessage>) -> Void
    
    @objc private func networkChanged() {
        connectIfNeeded()
    }
    
    private func reconnect(sendDisconnectToRemote: Bool) {
        queue.autoAsync {
            ReceiveMessageService.shared.refreshRefreshOneTimePreKeys = [String: TimeInterval]()
            for handler in self.messageHandlers.values {
                handler(.failure(.webSocketTimeOut))
            }
            self.messageHandlers.removeAll()
            ConcurrentJobQueue.shared.suspend()
            self.heartbeat?.stop()
            if sendDisconnectToRemote {
                self.socket?.disconnect(closeCode: CloseCode.failure)
            }
            self.status = .disconnected

            if ReachabilityManger.shared.isReachable {
                if -self.lastConnectionDate.timeIntervalSinceNow >= 2 {
                    self.connect()
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.connect()
                    }
                }
            } else {
                NotificationCenter.default.post(onMainThread: WebSocketService.didDisconnectNotification, object: self)
            }
        }
    }
    
    @discardableResult
    private func send(message: BlazeMessage) -> (success: Bool, isBadData: Bool) {
        guard let socket = socket, socket.isConnected else {
            return (false, false)
        }
        guard let data = try? JSONEncoder.default.encode(message), let gzipped = try? data.gzipped() else {
            reporter.report(error: MixinServicesError.gzipFailed)
            return (false, true)
        }
        guard gzipped.count < 120 * 1024 else {
            let conversationId = message.params?.conversationId ?? ""
            let category = message.params?.category ?? ""
            reporter.report(error: MixinServicesError.messageTooBig(gzipSize: gzipped.count, category: category, conversationId: conversationId))
            return (false, true)
        }
        
        socket.send(data: gzipped)
        return (true, false)
    }
    
    private func requestListPendingMessages() {
        let message: BlazeMessage
        if let offset = BlazeMessageDAO.shared.getLastBlazeMessageCreatedAt() {
            message = BlazeMessage(params: BlazeMessageParam(offset: offset), action: BlazeMessageAction.listPendingMessages.rawValue)
        } else {
            message = BlazeMessage(action: BlazeMessageAction.listPendingMessages.rawValue)
        }
        messageHandlers[message.id] = { (result) in
            switch result {
            case .success:
                if isAppExtension {
                    SendMessageService.shared.processMessages()
                } else {
                    NotificationCenter.default.post(onMainThread: Self.didSendListPendingMessageNotification, object: self)
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
