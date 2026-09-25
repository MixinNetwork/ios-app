import Foundation

protocol WebSocketConnectionDelegate: AnyObject {
    
    func webSocketConnectionDidOpen(
        _ connection: WebSocketConnection,
        serverTime: Double?,
    )
    
    func webSocketConnection(
        _ connection: WebSocketConnection,
        didReceiveData data: Data,
    )
    
    func webSocketConnection(
        _ connection: WebSocketConnection,
        didFailWithError error: any Error,
        shouldSwitchHost: Bool,
    )
    
    func webSocketConnection(
        _ connection: WebSocketConnection,
        didCloseWithCode code: URLSessionWebSocketTask.CloseCode,
        reason: String?,
    )
    
}

final class WebSocketConnection: NSObject {
    
    weak var delegate: (any WebSocketConnectionDelegate)?
    
    @Synchronized(value: false)
    private(set) var isConnected: Bool
    
    private let queue: DispatchQueue
    private let delegateOperationQueue: OperationQueue
    
    private var session: URLSession!
    private var currentTask: URLSessionWebSocketTask?
    
    private var heartbeatTimer: (any DispatchSourceTimer)?
    private var sentPingCount: Int = 0
    private var receivedPongCount: Int = 0
    private var lastPingDate: Date = Date()
    private var hasHandledTermination: Bool = false
    
    init(queue: DispatchQueue) {
        self.queue = queue
        let operationQueue = OperationQueue()
        operationQueue.underlyingQueue = queue
        operationQueue.maxConcurrentOperationCount = 1
        self.delegateOperationQueue = operationQueue
        super.init()
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        let proxy = SessionDelegateProxy(target: self)
        self.session = URLSession(
            configuration: configuration,
            delegate: proxy,
            delegateQueue: operationQueue,
        )
    }
    
    deinit {
        stopHeartbeat()
        session?.invalidateAndCancel()
    }
    
    func connect(request: URLRequest) {
        queue.async {
            self.disconnectCurrentTask(closeCode: .normalClosure)
            
            self.hasHandledTermination = false
            self.isConnected = false
            
            let task = self.session.webSocketTask(with: request)
            task.maximumMessageSize = BlazeMessageFramer.maxPayloadSize
            self.currentTask = task
            
            task.resume()
            self.startReceiving(for: task)
        }
    }
    
    func disconnect(closeCode: URLSessionWebSocketTask.CloseCode) {
        queue.async {
            self.stopHeartbeat()
            self.disconnectCurrentTask(closeCode: closeCode)
            self.isConnected = false
        }
    }
    
    func send(
        data: Data,
        completion: @escaping ((any Error)?) -> Void,
    ) {
        queue.async {
            guard self.isConnected, let task = self.currentTask, task.state == .running else {
                completion(URLError(.notConnectedToInternet))
                return
            }
            task.send(.data(data)) { error in
                completion(error)
            }
        }
    }
    
    func ping(completion: (((any Error)?) -> Void)?) {
        queue.async {
            guard let task = self.currentTask, task.state == .running else {
                completion?(URLError(.notConnectedToInternet))
                return
            }
            task.sendPing { error in
                completion?(error)
            }
        }
    }
    
    func checkConnection() {
        queue.async {
            guard self.isConnected, -self.lastPingDate.timeIntervalSinceNow >= 5 else {
                return
            }
            self.sendHeartbeatPing()
        }
    }
    
    private func disconnectCurrentTask(closeCode: URLSessionWebSocketTask.CloseCode) {
        if let task = currentTask {
            task.cancel(with: closeCode, reason: nil)
            currentTask = nil
        }
    }
    
    private func startReceiving(for task: URLSessionWebSocketTask) {
        task.receive { [weak self, weak task] result in
            guard let self, let task else {
                return
            }
            self.queue.async {
                guard self.currentTask === task else {
                    return
                }
                switch result {
                case let .success(message):
                    guard task.state == .running else {
                        return
                    }
                    switch message {
                    case let .data(data):
                        if data.count == 1 && data.first == 0x9 {
                            self.ping(completion: nil)
                        } else {
                            self.delegate?.webSocketConnection(
                                self,
                                didReceiveData: data,
                            )
                        }
                    case let .string(text):
                        if let data = text.data(using: .utf8) {
                            self.delegate?.webSocketConnection(
                                self,
                                didReceiveData: data,
                            )
                        }
                    @unknown default:
                        break
                    }
                    self.startReceiving(for: task)
                    
                case let .failure(error):
                    self.handleTaskTermination(
                        error: error,
                        for: task,
                    )
                }
            }
        }
    }
    
    private func startHeartbeat() {
        stopHeartbeat()
        sentPingCount = 0
        receivedPongCount = 0
        lastPingDate = Date()
        
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(
            deadline: .now() + 15,
            repeating: 15,
        )
        timer.setEventHandler { [weak self] in
            self?.sendHeartbeatPing()
        }
        timer.resume()
        heartbeatTimer = timer
    }
    
    private func stopHeartbeat() {
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
        sentPingCount = 0
        receivedPongCount = 0
    }
    
    private func sendHeartbeatPing() {
        guard isConnected, let task = currentTask, task.state == .running else {
            return
        }
        if sentPingCount > receivedPongCount {
            guard -lastPingDate.timeIntervalSinceNow >= 15 else {
                return
            }
            Logger.general.error(
                category: "WebSocketConnection",
                message: "Heartbeat ping timed out (sent: \(sentPingCount), received: \(receivedPongCount))"
            )
            handleTaskTermination(
                error: URLError(.timedOut),
                for: task,
            )
        } else {
            lastPingDate = Date()
            sentPingCount += 1
            heartbeatTimer?.schedule(
                deadline: .now() + 15,
                repeating: 15,
            )
            task.sendPing { [weak self, weak task] error in
                guard let self, let task else {
                    return
                }
                self.queue.async {
                    guard self.currentTask === task else {
                        return
                    }
                    if let error {
                        Logger.general.error(
                            category: "WebSocketConnection",
                            message: "Heartbeat ping failed: \(error)",
                        )
                        self.handleTaskTermination(
                            error: error,
                            for: task,
                        )
                    } else {
                        self.receivedPongCount += 1
                    }
                }
            }
        }
    }
    
    private func handleTaskTermination(
        error: (any Error)?,
        for task: URLSessionWebSocketTask,
    ) {
        guard currentTask === task, !hasHandledTermination else {
            return
        }
        hasHandledTermination = true
        isConnected = false
        stopHeartbeat()
        
        let isCancelled: Bool
        if let error {
            let nsError = error as NSError
            isCancelled = (nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled)
        } else {
            isCancelled = false
        }
        
        guard !isCancelled else {
            return
        }
        
        let shouldSwitchHost: Bool
        if let error {
            shouldSwitchHost = self.shouldSwitchHost(
                for: error,
                task: task,
            )
        } else {
            shouldSwitchHost = false
        }
        
        let terminationError = error ?? URLError(.networkConnectionLost)
        var responseDetails = ""
        if let httpResponse = task.response as? HTTPURLResponse {
            responseDetails = ", httpStatus: \(httpResponse.statusCode), headers: \(httpResponse.allHeaderFields)"
        }
        Logger.general.error(
            category: "WebSocketConnection",
            message: "WebSocket connection terminated: \(terminationError)\(responseDetails), shouldSwitchHost: \(shouldSwitchHost)"
        )
        
        delegate?.webSocketConnection(
            self,
            didFailWithError: terminationError,
            shouldSwitchHost: shouldSwitchHost,
        )
    }
    
    private func shouldSwitchHost(
        for error: any Error,
        task: URLSessionWebSocketTask?,
    ) -> Bool {
        if let httpResponse = task?.response as? HTTPURLResponse, httpResponse.statusCode >= 500 {
            return true
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorDNSLookupFailed,
                 NSURLErrorCannotFindHost,
                 NSURLErrorBadServerResponse,
                 NSURLErrorCannotParseResponse,
                 NSURLErrorSecureConnectionFailed,
                 NSURLErrorServerCertificateHasBadDate,
                 NSURLErrorServerCertificateUntrusted,
                 NSURLErrorServerCertificateHasUnknownRoot,
                 NSURLErrorServerCertificateNotYetValid:
                return true
            default:
                return false
            }
        } else if nsError.domain == NSPOSIXErrorDomain {
            switch nsError.code {
            case 54, 57, 61: // ECONNRESET, ENOTCONN, ECONNREFUSED
                return true
            default:
                return false
            }
        }
        return false
    }
    
}

extension WebSocketConnection: URLSessionWebSocketDelegate {
    
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?,
    ) {
        queue.async {
            guard self.currentTask === webSocketTask else {
                return
            }
            self.isConnected = true
            self.hasHandledTermination = false
            
            var serverTime: Double?
            if let response = webSocketTask.response as? HTTPURLResponse {
                let headerValue = response.value(forHTTPHeaderField: "x-server-time")
                    ?? (response.allHeaderFields["x-server-time"] as? String)
                if let headerValue, let time = Double(headerValue) {
                    serverTime = time
                }
            }
            
            self.startHeartbeat()
            self.delegate?.webSocketConnectionDidOpen(
                self,
                serverTime: serverTime,
            )
        }
    }
    
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?,
    ) {
        queue.async {
            guard self.currentTask === webSocketTask, !self.hasHandledTermination else {
                return
            }
            self.hasHandledTermination = true
            self.isConnected = false
            self.stopHeartbeat()
            
            let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) }
            let errType: String
            
            switch closeCode {
            case .invalid:
                errType = "invalid"
            case .normalClosure:
                errType = "normalClosure"
            case .goingAway:
                errType = "goingAway"
            case .protocolError:
                errType = "protocolError"
            case .unsupportedData:
                errType = "unsupportedData"
            case .noStatusReceived:
                errType = "noStatusReceived"
            case .abnormalClosure:
                errType = "abnormalClosure"
            case .invalidFramePayloadData:
                errType = "invalidFramePayloadData"
            case .policyViolation:
                errType = "policyViolation"
            case .messageTooBig:
                errType = "messageTooBig"
            case .mandatoryExtensionMissing:
                errType = "mandatoryExtensionMissing"
            case .internalServerError:
                errType = "internalServerError"
            case .tlsHandshakeFailure:
                errType = "tlsHandshakeFailure"
            @unknown default:
                errType = "\(closeCode.rawValue)"
            }
            
            Logger.general.error(
                category: "WebSocketConnection",
                message: "WebSocket closed with: \(errType), code: \(closeCode.rawValue), reason: \(reasonString ?? "")"
            )
            
            if closeCode != .normalClosure && closeCode != .goingAway {
                reporter.report(
                    error: MixinServicesError.websocketError(
                        errType: errType,
                        errMessage: reasonString ?? errType,
                        errCode: closeCode.rawValue
                    )
                )
            }
            
            self.delegate?.webSocketConnection(
                self,
                didCloseWithCode: closeCode,
                reason: reasonString,
            )
        }
    }
    
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?,
    ) {
        queue.async {
            guard let webSocketTask = task as? URLSessionWebSocketTask,
                  self.currentTask === webSocketTask else {
                return
            }
            if let error {
                self.handleTaskTermination(
                    error: error,
                    for: webSocketTask,
                )
            }
        }
    }
    
}

private final class SessionDelegateProxy: NSObject, URLSessionWebSocketDelegate {
    
    weak var target: WebSocketConnection?
    
    init(target: WebSocketConnection) {
        self.target = target
    }
    
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?,
    ) {
        target?.urlSession(
            session,
            webSocketTask: webSocketTask,
            didOpenWithProtocol: `protocol`,
        )
    }
    
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?,
    ) {
        target?.urlSession(
            session,
            webSocketTask: webSocketTask,
            didCloseWith: closeCode,
            reason: reason,
        )
    }
    
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?,
    ) {
        target?.urlSession(
            session,
            task: task,
            didCompleteWithError: error,
        )
    }
    
}
