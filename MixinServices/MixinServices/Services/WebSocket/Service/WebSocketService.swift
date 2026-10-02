import Foundation

public final class WebSocketService {
    
    public enum SendingError: Error, Sendable {
        case timedOut
        case response(MixinAPIResponseError)
        case framing(BlazeMessageFramer.FramingError)
    }
    
    public enum Status: String, Sendable {
        case disconnected
        case connecting
        case connected
    }
    
    public static let didConnectNotification = Notification.Name("one.mixin.services.ws.connect")
    public static let didDisconnectNotification = Notification.Name("one.mixin.services.ws.disconnect")
    public static let didSendListPendingMessageNotification = Notification.Name("one.mixin.services.ws.pending")
    
    public static let shared = WebSocketService()
    
    @Synchronized(value: .disconnected)
    public private(set) var status: Status
    
    public var isConnected: Bool {
        status == .connected
    }
    
    private let queue = Queue(
        label: "one.mixin.services.queue.websocket",
        qos: .userInitiated
    )
    private let messageQueue = DispatchQueue(
        label: "one.mixin.services.queue.websocket.message"
    )
    
    private let connection: WebSocketConnection
    private let requestManager = WebSocketRequestManager()
    
    private var host: String?
    private var handshakeSigningDate = Date()
    private var lastConnectionDate = Date()
    
    internal init() {
        let connection = WebSocketConnection(queue: queue.dispatchQueue)
        self.connection = connection
        connection.delegate = self
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(networkChanged),
            name: ReachabilityManger.reachabilityDidChangeNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    public func connect() {
        queue.autoAsync {
            guard canProcessMessages else {
                return
            }
            guard ReachabilityManger.shared.isReachable else {
                self.reconnect(shouldCloseExistingConnection: true)
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
            
            self.host = MixinHost.webSocket
            self.updateStatus(.connecting)
            
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            request.allHTTPHeaderFields = RequestSigning.signedHeaders(for: request)
            let subprotocol = isAppExtension ? "Mixin-Notification-Extension-1" : "Mixin-Blaze-1"
            request.setValue(
                subprotocol,
                forHTTPHeaderField: "Sec-WebSocket-Protocol"
            )
            
            self.lastConnectionDate = Date()
            self.handshakeSigningDate = Date()
            self.connection.connect(request: request)
        }
    }
    
    public func disconnect() {
        queue.autoAsync {
            self.connection.disconnect(closeCode: .normalClosure)
            ConcurrentJobQueue.shared.cancelAllOperations()
            self.requestManager.failAll(with: .timedOut)
            self.updateStatus(.disconnected)
        }
    }
    
    public func connectIfNeeded() {
        queue.autoAsync {
            guard canProcessMessages else {
                return
            }
            guard ReachabilityManger.shared.isReachable else {
                self.reconnect(shouldCloseExistingConnection: true)
                return
            }
            if self.status == .connected {
                if self.connection.isConnected {
                    self.connection.checkConnection()
                } else {
                    self.reconnect(shouldCloseExistingConnection: true)
                }
            } else if self.status == .disconnected {
                self.connect()
            }
        }
    }
    
    // MARK: - Message Request & Response
    
    internal func requestSync(
        _ message: BlazeMessage,
        timeout: TimeInterval?,
    ) throws(SendingError) -> BlazeMessage {
        do {
            return try messageQueue.sync {
                guard LoginManager.shared.isLoggedIn else {
                    throw SendingError.timedOut
                }
                guard isConnected else {
                    throw SendingError.timedOut
                }
                
                let timeoutInterval = timeout ?? requestTimeout
                var response: BlazeMessage?
                var sendingError: SendingError = .timedOut
                let semaphore = DispatchSemaphore(value: 0)
                
                requestManager.register(
                    message: message,
                    timeout: timeoutInterval,
                ) { result in
                    switch result {
                    case let .success(blazeMessage):
                        response = blazeMessage
                    case let .failure(error):
                        sendingError = error
                    }
                    semaphore.signal()
                }
                
                do {
                    let gzippedData = try BlazeMessageFramer.encodeAndCompress(message: message)
                    connection.send(data: gzippedData) { [weak self] error in
                        if let error {
                            Logger.general.error(
                                category: "WebSocketService",
                                message: "Failed to send frame: \(error)",
                            )
                            self?.requestManager.fail(
                                messageID: message.id,
                                with: .timedOut,
                            )
                        }
                    }
                } catch let error as BlazeMessageFramer.FramingError {
                    requestManager.cancel(messageID: message.id)
                    throw SendingError.framing(error)
                } catch {
                    requestManager.cancel(messageID: message.id)
                    throw SendingError.timedOut
                }
                
                semaphore.wait()
                
                guard let blazeMessage = response else {
                    throw sendingError
                }
                return blazeMessage
            }
        } catch let error as SendingError {
            throw error
        } catch {
            throw SendingError.timedOut
        }
    }
    
    internal func request(
        _ message: BlazeMessage,
        timeout: TimeInterval?,
        completion: @escaping (Result<BlazeMessage, SendingError>) -> Void,
    ) {
        guard LoginManager.shared.isLoggedIn, isConnected else {
            completion(.failure(.timedOut))
            return
        }
        
        let timeoutInterval = timeout ?? requestTimeout
        requestManager.register(
            message: message,
            timeout: timeoutInterval,
        ) { result in
            completion(result)
        }
        
        do {
            let gzippedData = try BlazeMessageFramer.encodeAndCompress(message: message)
            connection.send(data: gzippedData) { [weak self] error in
                if let error {
                    Logger.general.error(
                        category: "WebSocketService",
                        message: "Failed to send frame: \(error)",
                    )
                    self?.requestManager.fail(
                        messageID: message.id,
                        with: .timedOut,
                    )
                }
            }
        } catch let error as BlazeMessageFramer.FramingError {
            requestManager.cancel(messageID: message.id)
            completion(.failure(.framing(error)))
        } catch {
            requestManager.cancel(messageID: message.id)
            completion(.failure(.timedOut))
        }
    }
    
    private func updateStatus(_ newStatus: Status) {
        guard status != newStatus || newStatus == .disconnected else {
            return
        }
        status = newStatus
        
        switch newStatus {
        case .connected:
            NotificationCenter.default.post(
                onMainThread: WebSocketService.didConnectNotification,
                object: self,
            )
        case .disconnected:
            NotificationCenter.default.post(
                onMainThread: WebSocketService.didDisconnectNotification,
                object: self,
            )
        case .connecting:
            break
        }
    }
    
    private func requestListPendingMessages() {
        let message: BlazeMessage
        if let offset = BlazeMessageDAO.shared.getLastBlazeMessageCreatedAt() {
            message = BlazeMessage(
                params: BlazeMessageParam(offset: offset),
                action: BlazeMessageAction.listPendingMessages.rawValue
            )
        } else {
            message = BlazeMessage(
                action: BlazeMessageAction.listPendingMessages.rawValue
            )
        }
        
        requestManager.register(
            message: message,
            timeout: requestTimeout
        ) { [weak self] result in
            guard let self else {
                return
            }
            switch result {
            case .success:
                if isAppExtension {
                    SendMessageService.shared.processMessages()
                } else {
                    NotificationCenter.default.post(
                        onMainThread: Self.didSendListPendingMessageNotification,
                        object: self
                    )
                }
            case .failure:
                self.queue.asyncAfter(
                    deadline: .now() + 2,
                    execute: { [weak self] in
                        guard let self, self.isConnected else {
                            return
                        }
                        self.requestListPendingMessages()
                    }
                )
            }
        }
        
        do {
            let data = try BlazeMessageFramer.encodeAndCompress(message: message)
            connection.send(data: data) { [weak self] error in
                if let error {
                    Logger.general.error(
                        category: "WebSocketService",
                        message: "Failed to send listPendingMessages frame: \(error)",
                    )
                    self?.requestManager.fail(
                        messageID: message.id,
                        with: .timedOut,
                    )
                }
            }
        } catch {
            requestManager.fail(
                messageID: message.id,
                with: .timedOut,
            )
        }
    }
    
}

extension WebSocketService {
    
    @objc private func networkChanged() {
        connectIfNeeded()
    }
    
    private func reconnect(shouldCloseExistingConnection: Bool) {
        queue.autoAsync {
            ReceiveMessageService.shared.refreshRefreshOneTimePreKeys.removeAll()
            self.requestManager.failAll(with: .timedOut)
            ConcurrentJobQueue.shared.suspend()
            if shouldCloseExistingConnection {
                self.connection.disconnect(closeCode: .goingAway)
            }
            self.updateStatus(.disconnected)
            
            if ReachabilityManger.shared.isReachable {
                if -self.lastConnectionDate.timeIntervalSinceNow >= 2 {
                    self.connect()
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.connect()
                    }
                }
            }
        }
    }
    
}

extension WebSocketService: WebSocketConnectionDelegate {
    
    func webSocketConnectionDidOpen(
        _ connection: WebSocketConnection,
        serverTime: Double?,
    ) {
        guard status == .connecting else {
            return
        }
        if let serverTime, serverTime > 0 {
            let signingDate = handshakeSigningDate
            let date = Date(timeIntervalSince1970: serverTime / 1_000_000_000)
            if abs(date.timeIntervalSince(signingDate)) > 300 {
                if -signingDate.timeIntervalSinceNow > 60 {
                    reconnect(shouldCloseExistingConnection: true)
                } else {
                    AppGroupUserDefaults.isClockSkewed = true
                    disconnect()
                    NotificationCenter.default.post(
                        onMainThread: MixinService.clockSkewDetectedNotification,
                        object: self
                    )
                }
                return
            }
        }
        updateStatus(.connected)
        ReceiveMessageService.shared.processReceiveMessages()
        requestListPendingMessages()
        ConcurrentJobQueue.shared.resume()
    }
    
    func webSocketConnection(
        _ connection: WebSocketConnection,
        didFailWithError error: any Error,
        shouldSwitchHost: Bool,
    ) {
        guard status == .connecting || status == .connected else {
            return
        }
        if shouldSwitchHost {
            MixinHost.toggle(currentWebSocketHost: host)
        }
        reconnect(shouldCloseExistingConnection: false)
    }
    
    func webSocketConnection(
        _ connection: WebSocketConnection,
        didCloseWithCode code: URLSessionWebSocketTask.CloseCode,
        reason: String?,
    ) {
        guard status == .connecting || status == .connected else {
            return
        }
        if code == .noStatusReceived {
            MixinHost.toggle(currentWebSocketHost: host)
        }
        reconnect(shouldCloseExistingConnection: false)
    }
    
    func webSocketConnection(
        _ connection: WebSocketConnection,
        didReceiveData data: Data,
    ) {
        guard let message = try? BlazeMessageFramer.decompressAndDecode(data: data) else {
            return
        }
        let wasResolved = requestManager.resolve(with: message)
        if let error = message.error {
            if case .unauthorized = error, message.action == BlazeMessageAction.error.rawValue, !AppGroupUserDefaults.isClockSkewed {
                LoginManager.shared.logout(reason: "WS access unauthorized: \(message.id)")
            }
        } else if message.data != nil {
            if message.isReceiveMessageAction() {
                ReceiveMessageService.shared.receiveMessage(blazeMessage: message)
            } else if !wasResolved {
                guard let data = message.toBlazeMessageData() else {
                    return
                }
                SendMessageService.shared.sendAckMessage(messageId: data.messageId, status: .READ)
            }
        }
    }
    
}
