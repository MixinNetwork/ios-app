import Foundation
import Network
import MixinServices

final class DeviceTransferServer {
    
    enum ConnectionRejectedReason {
        case mismatchedUser
        case mismatchedCode
    }
    
    enum State {
        case idle
        case listening(hostname: String, port: UInt16)
        case transfer(progress: Float, speed: String) // `progress` is between 0.0 and 1.0
        case closed(ClosedReason)
    }
    
    enum ClosedReason {
        case finished
        case exception(DeviceTransferError)
    }
    
    let code: UInt16 = .random(in: 0...999)
    let key = DeviceTransferKey()
    
    // Access on the private `queue`
    @Published private(set) var state: State = .idle
    
    // Access on main queue
    @Published private(set) var lastConnectionRejectedReason: ConnectionRejectedReason?
    
    private let queue = Queue(label: "one.mixin.messenger.DeviceTransferServer")
    private let dataLoaderQueue = Queue(label: "one.mixin.messenger.DeviceTransferServer.Loader")
    private let speedInspector = NetworkSpeedInspector()
    private let maxMemoryConsumption = 10 * Int(bytesPerMegaByte)
    private let maxWaitingTimeIntervalUntilContentProcessed: TimeInterval = 10
    
    // Access on the private `queue`
    private var listener: NWListener?
    private var connection: NWConnection?
    
    private weak var speedInspectingTimer: Timer?
    
    private var opaquePointer: UnsafeMutableRawPointer {
        Unmanaged<DeviceTransferServer>.passUnretained(self).toOpaque()
    }
    
    init() {
        Logger.general.info(category: "DeviceTransferServer", message: "\(opaquePointer) init")
    }
    
    deinit {
        Logger.general.info(category: "DeviceTransferServer", message: "\(opaquePointer) deinit")
    }
    
}

// MARK: - Listening Connection
extension DeviceTransferServer {
    
    func startListening(onFailure: @escaping (Error) -> Void) {
        queue.async { [weak self] in
            guard self?.listener == nil else {
                Logger.general.warn(category: "DeviceTransferServer", message: "Listener inited")
                return
            }
            
            let listener: NWListener
            do {
                listener = try NWListener(using: .deviceTransfer)
            } catch {
                onFailure(error)
                return
            }
            
            listener.stateUpdateHandler = { [unowned listener] state in
                switch state {
                case .ready:
                    do {
                        let hostname = try NetworkInterface.firstEthernetHostname()
                        switch (self, listener.port) {
                        case (nil, _):
                            Logger.general.warn(category: "DeviceTransferServer", message: "Listener ready after server deinited")
                        case (_, nil):
                            Logger.general.warn(category: "DeviceTransferServer", message: "Listener ready without a port")
                        case let (.some(self), .some(port)):
                            Logger.general.info(category: "DeviceTransferServer", message: "Listening on [\(hostname)]:\(port.rawValue)")
                            self.state = .listening(hostname: hostname, port: port.rawValue)
                        }
                    } catch {
                        Logger.general.warn(category: "DeviceTransferServer", message: "Listener ready without a hostname")
                        self?.state = .closed(.exception(.connectionFailed(error)))
                    }
                case let .failed(error), let .waiting(error):
                    Logger.general.warn(category: "DeviceTransferServer", message: "Not listening: \(error)")
                case .setup:
                    Logger.general.info(category: "DeviceTransferServer", message: "Setting up listener")
                case .cancelled:
                    Logger.general.info(category: "DeviceTransferServer", message: "Listener cancelled")
                @unknown default:
                    break
                }
            }
            listener.newConnectionHandler = { [unowned listener] connection in
                listener.cancel()
                if let self {
                    if listener === self.listener {
                        self.listener = nil
                    }
                    self.startNewConnection(connection)
                }
            }
            
            if let self {
                self.listener = listener
                listener.start(queue: self.queue.dispatchQueue)
            }
        }
    }
    
    func stopListening() {
        queue.async {
            self.listener?.cancel()
            self.listener = nil
        }
    }
    
}

// MARK: - Speed Inspecting
extension DeviceTransferServer {
    
    private func startSpeedInspecting() {
        assert(Queue.main.isCurrent)
        speedInspectingTimer?.invalidate()
        speedInspector.clear()
        speedInspectingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else {
                Logger.general.warn(category: "DeviceTransferServer", message: "Timer fired after deinited")
                return
            }
            let speed = self.speedInspector.drain()
            self.queue.async {
                if case let .transfer(progress, _) = self.state {
                    self.state = .transfer(progress: progress, speed: speed)
                }
            }
        }
    }
    
    private func stopSpeedInspecting() {
        assert(Queue.main.isCurrent)
        speedInspectingTimer?.invalidate()
    }
    
}

// MARK: - Signaling
extension DeviceTransferServer {
    
    func consumeLastConnectionBlockedReason() {
        assert(Queue.main.isCurrent)
        lastConnectionRejectedReason = nil
    }
    
    private func stop(reason: ClosedReason) {
        assert(queue.isCurrent)
        Logger.general.info(category: "DeviceTransferServer", message: "Stop with reason: \(reason)")
        listener?.cancel()
        listener = nil
        connection?.cancel()
        connection = nil
        DispatchQueue.main.sync(execute: stopSpeedInspecting)
        switch reason {
        case .finished:
            state = .closed(.finished)
        case .exception(let error):
            state = .closed(.exception(error))
        }
    }
    
    private func rejectCurrentConnection(reason: ConnectionRejectedReason) {
        assert(queue.isCurrent)
        DispatchQueue.main.sync {
            self.lastConnectionRejectedReason = reason
        }
        if let connection {
            connection.cancel()
            self.connection = nil
        }
        startListening { error in
            Logger.general.error(category: "DeviceTransferServer", message: "Failed to start listening after connection rejected")
            self.state = .closed(.exception(.connectionFailed(error)))
        }
    }
    
    private func startNewConnection(_ connection: NWConnection) {
        assert(queue.isCurrent)
        guard self.connection == nil else {
            Logger.general.warn(category: "DeviceTransferServer", message: "New connection cancelled")
            connection.cancel()
            return
        }
        self.connection = connection
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .setup:
                Logger.general.info(category: "DeviceTransferServer", message: "Setting up new connection")
            case .waiting(let error):
                Logger.general.warn(category: "DeviceTransferServer", message: "Waiting: \(error)")
            case .preparing:
                Logger.general.info(category: "DeviceTransferServer", message: "Preparing new connection")
            case .ready:
                Logger.general.info(category: "DeviceTransferServer", message: "Connection ready")
                if let self {
                    self.continueReceiving(connection: connection)
                    DispatchQueue.main.async(execute: self.startSpeedInspecting)
                }
            case .failed(let error):
                Logger.general.warn(category: "DeviceTransferServer", message: "Failed: \(error)")
                self?.stop(reason: .exception(.connectionFailed(error)))
            case .cancelled:
                Logger.general.info(category: "DeviceTransferServer", message: "Connection cancelled")
            @unknown default:
                break
            }
        }
        connection.start(queue: queue.dispatchQueue)
    }
    
    private func continueReceiving(connection: NWConnection) {
        connection.receiveMessage { [weak self] completeContent, contentContext, isComplete, error in
            guard let self else {
                Logger.general.warn(category: "DeviceTransferServer", message: "Receiving message after server deinited")
                return
            }
            assert(self.queue.isCurrent)
            
            guard
                let content = completeContent,
                let message = contentContext?.protocolMetadata(definition: DeviceTransferProtocol.definition) as? NWProtocolFramer.Message
            else {
                switch error {
                case .posix(.ECANCELED):
                    Logger.general.info(category: "DeviceTransferServer", message: "Stop receiving on cancellation")
                case .some(let error):
                    Logger.general.error(category: "DeviceTransferServer", message: "Stop receiving on: \(error)")
                case .none:
                    Logger.general.warn(category: "DeviceTransferServer", message: "Stop receiving with content: \(completeContent?.count ?? -1), context: \(String(describing: contentContext)), complete: \(isComplete)")
                }
                return
            }
            
            if let header = message[DeviceTransferProtocol.MessageKey.header] as? DeviceTransferHeader {
                switch header.type {
                case .command:
                    let firstHMACIndex = content.endIndex.advanced(by: -DeviceTransferProtocol.hmacDataCount)
                    let encryptedData = content[..<firstHMACIndex]
                    let remoteHMAC = content[firstHMACIndex...]
                    let localHMAC = HMACSHA256.mac(for: encryptedData, using: self.key.hmac)
                    guard localHMAC == remoteHMAC else {
                        self.stop(reason: .exception(.mismatchedHMAC(local: localHMAC, remote: remoteHMAC)))
                        return
                    }
                    do {
                        let decryptedData = try AESCryptor.decrypt(encryptedData, with: self.key.aes)
                        let command = try JSONDecoder.default.decode(DeviceTransferCommand.self, from: decryptedData)
                        self.handle(command: command, on: connection)
                    } catch {
                        Logger.general.error(category: "DeviceTransferServer", message: "Unable to decode the command: \(error)")
                    }
                case .message:
                    Logger.general.warn(category: "DeviceTransferServer", message: "Received a message from remote")
                case .file:
                    Logger.general.warn(category: "DeviceTransferServer", message: "Received a file from remote")
                }
            } else {
                Logger.general.warn(category: "DeviceTransferServer", message: "Received data without a header")
            }
            
            if let error {
                Logger.general.error(category: "DeviceTransferServer", message: "Error receiving message: \(error)")
            } else {
                self.continueReceiving(connection: connection)
            }
        }
    }
    
    private func handle(command: DeviceTransferCommand, on connection: NWConnection) {
        assert(queue.isCurrent)
        switch command.action {
        case let .connect(code, userID):
            if userID != myUserId {
                rejectCurrentConnection(reason: .mismatchedUser)
            } else if code != self.code {
                rejectCurrentConnection(reason: .mismatchedCode)
            } else {
                state = .transfer(progress: 0, speed: "")
                queue.async {
                    self.startTransfer(on: connection, remotePlatform: command.platform)
                }
            }
        case .finish:
            self.stop(reason: .finished)
        case let .progress(progress):
            if case let .transfer(_, speed) = state {
                state = .transfer(progress: progress, speed: speed)
            } else {
                Logger.general.warn(category: "DeviceTransferServer", message: "Drop progress command")
            }
        case .pull, .push, .start, .cancel:
            Logger.general.warn(category: "DeviceTransferServer", message: "Invalid command: \(command)")
        }
    }
    
}

// MARK: - Data Transfer
extension DeviceTransferServer {
    
    private func startTransfer(on connection: NWConnection, remotePlatform: DeviceTransferPlatform) {
        assert(queue.isCurrent)
        guard case .transfer = state else {
            Logger.general.warn(category: "DeviceTransferServer", message: "Not transfering due to invalid state")
            return
        }
        let dataSource = DeviceTransferServerDataSource(key: key, remotePlatform: remotePlatform)
        let count = dataSource.totalCount()
        let start = DeviceTransferCommand(action: .start(count))
        do {
            let data = try DeviceTransferProtocol.output(command: start, key: key)
            guard connection === self.connection else {
                stop(reason: .exception(.mismatchedConnection))
                return
            }
            connection.send(content: data, completion: .contentProcessed({ error in
                if let error {
                    Logger.general.error(category: "DeviceTransferServer", message: "Error sending start command: \(error)")
                } else {
                    self.transferData(dataSource: dataSource, connection: connection)
                }
            }))
        } catch {
            Logger.general.error(category: "DeviceTransferServer", message: "Failed to output start command: \(error)")
            stop(reason: .exception(.encrypt(error)))
        }
    }
    
    private func transferData(dataSource: DeviceTransferServerDataSource, connection: NWConnection) {
        assert(self.queue.isCurrent)
        let speedConditioner = NetworkSpeedConditioner(maxCount: maxMemoryConsumption,
                                                       timeoutInterval: maxWaitingTimeIntervalUntilContentProcessed)
        dataLoaderQueue.async { [weak self, key] in
            do {
                try dataSource.enumerateItems { data, stop in
                    guard let self else {
                        Logger.general.error(category: "DeviceTransferServer", message: "Stop transfering due to server deinited")
                        stop = true
                        return
                    }
                    let count = data.count
                    if speedConditioner.wait(count) == .timedOut {
                        Logger.general.warn(category: "DeviceTransferServer", message: "SpeedConditioner timeout")
                    }
                    if connection.state == .ready {
                        connection.send(content: data, completion: .contentProcessed({ error in
                            assert(self.queue.isCurrent)
                            speedConditioner.signal(count)
                            DispatchQueue.main.async {
                                self.speedInspector.add(byteCount: count)
                            }
                            if let error {
                                Logger.general.error(category: "DeviceTransferServer", message: "Failed to send: \(error)")
                            }
                        }))
                    } else {
                        Logger.general.error(category: "DeviceTransferServer", message: "Stop transfering due to connection is not ready: \(connection.state)")
                        stop = true
                    }
                }
                let finish = DeviceTransferCommand(action: .finish)
                let data = try DeviceTransferProtocol.output(command: finish, key: key)
                connection.send(content: data, completion: .idempotent)
            } catch {
                Logger.general.error(category: "DeviceTransferServer", message: "Failed to transfer: \(error)")
                self?.queue.async {
                    self?.stop(reason: .exception(.encrypt(error)))
                }
            }
        }
    }
    
}
