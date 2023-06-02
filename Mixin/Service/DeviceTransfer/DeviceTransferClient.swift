import Foundation
import Network
import MixinServices

final class DeviceTransferClient {
    
    enum State {
        case idle
        case transfer(progress: Double, speed: String)
        case closed(DeviceTransferClosedReason)
        case importing(progress: Float)
        case finished
    }
    
    @Published private(set) var state: State = .idle
    
    private let hostname: String
    private let port: UInt16
    private let code: UInt16
    private let key: DeviceTransferKey
    private let remotePlatform: DeviceTransferPlatform
    private let connection: NWConnection
    private let queue = Queue(label: "one.mixin.messenger.DeviceTransferClient")
    private let speedInspector = NetworkSpeedInspector()
    private let dataWriter: DeviceTransferDataWriter
    
    private weak var statisticsTimer: Timer?
    
    private var fileStream: DeviceTransferFileStream?
    
    // Access counts on main queue
    private var processedCount = 0
    private var totalCount: Int?
    
    private var opaquePointer: UnsafeMutableRawPointer {
        Unmanaged<DeviceTransferClient>.passUnretained(self).toOpaque()
    }
    
    init(hostname: String, port: UInt16, code: UInt16, key: DeviceTransferKey, remotePlatform: DeviceTransferPlatform) {
        self.hostname = hostname
        self.port = port
        self.code = code
        self.key = key
        self.remotePlatform = remotePlatform
        self.connection = {
            let host = NWEndpoint.Host(hostname)
            let port = NWEndpoint.Port(integerLiteral: port)
            let endpoint = NWEndpoint.hostPort(host: host, port: port)
            return NWConnection(to: endpoint, using: .deviceTransfer)
        }()
        self.dataWriter = DeviceTransferDataWriter(remotePlatform: remotePlatform)
        Logger.general.info(category: "DeviceTransferClient", message: "\(opaquePointer) init")
    }
    
    deinit {
        Logger.general.info(category: "DeviceTransferClient", message: "\(opaquePointer) deinit")
    }
    
    func start() {
        Logger.general.info(category: "DeviceTransferClient", message: "Will start connecting to [\(hostname)]:\(port)")
        connection.stateUpdateHandler = { [weak self, unowned connection] state in
            switch state {
            case .setup:
                Logger.general.info(category: "DeviceTransferClient", message: "Setting up new connection")
            case .waiting(let error):
                Logger.general.warn(category: "DeviceTransferClient", message: "Waiting: \(error)")
            case .preparing:
                Logger.general.info(category: "DeviceTransferClient", message: "Preparing new connection")
            case .ready:
                Logger.general.info(category: "DeviceTransferClient", message: "Connection ready")
                if let self {
                    do {
                        DispatchQueue.main.sync(execute: self.speedInspector.clear)
                        let connect = DeviceTransferCommand(action: .connect(code: self.code, userID: myUserId))
                        let content = try DeviceTransferProtocol.output(command: connect, key: self.key)
                        self.continueReceiving(connection: connection)
                        connection.send(content: content, completion: .idempotent)
                        Logger.general.info(category: "DeviceTransferClient", message: "Sent connect command: \(connect)")
                    } catch {
                        connection.cancel()
                        Logger.general.error(category: "DeviceTransferClient", message: "Unable to output connect command: \(error)")
                    }
                } else {
                    Logger.general.error(category: "DeviceTransferClient", message: "Connection ready after self deinited")
                }
            case .failed(let error):
                Logger.general.warn(category: "DeviceTransferClient", message: "Failed: \(error)")
                if let self {
                    self.stop(reason: .exception(.failed(error)))
                }
            case .cancelled:
                Logger.general.info(category: "DeviceTransferClient", message: "Connection cancelled")
            @unknown default:
                break
            }
        }
        connection.start(queue: queue.dispatchQueue)
    }
    
    func stop(reason: DeviceTransferClosedReason) {
        assert(queue.isCurrent)
        Logger.general.info(category: "DeviceTransferClient", message: "Stop: \(reason) Processed: \(processedCount) Total: \(totalCount)")
        DispatchQueue.main.sync {
            self.statisticsTimer?.invalidate()
        }
        connection.cancel()
        switch reason {
        case .finished:
            state = .closed(.finished)
        case .exception(let error):
            DispatchQueue.main.async {
                self.dataWriter.delegate = nil
                self.dataWriter.canProcessData = false
            }
            state = .closed(.exception(error))
        }
    }
    
    private func startUpdatingProgressAndSpeed() {
        assert(Queue.main.isCurrent)
        statisticsTimer?.invalidate()
        statisticsTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                Logger.general.warn(category: "DeviceTransferClient", message: "Statistic timer fired after self deinited")
                return
            }
            let speed = self.speedInspector.drain()
            let progress: Double
            if let totalCount = self.totalCount {
                progress = Double(self.processedCount) * 100 / Double(totalCount)
            } else {
                progress = 0
            }
            self.queue.async {
                guard case .transfer = self.state else {
                    DispatchQueue.main.sync(execute: timer.invalidate)
                    Logger.general.warn(category: "DeviceTransferClient", message: "Statistic timer fired on: \(self.state)")
                    return
                }
                self.state = .transfer(progress: progress, speed: speed)
                let command = DeviceTransferCommand(action: .progress(progress))
                do {
                    let content = try DeviceTransferProtocol.output(command: command, key: self.key)
                    self.connection.send(content: content, completion: .idempotent)
                    Logger.general.info(category: "DeviceTransferClient", message: "Report progress: \(progress), speed: \(speed)")
                } catch {
                    Logger.general.error(category: "DeviceTransferClient", message: "Failed to report statistics: \(error)")
                }
            }
        }
    }
    
}

extension DeviceTransferClient {
    
    private func continueReceiving(connection: NWConnection) {
        connection.receiveMessage { completeContent, contentContext, isComplete, error in
            guard
                let content = completeContent,
                let message = contentContext?.protocolMetadata(definition: DeviceTransferProtocol.definition) as? NWProtocolFramer.Message
            else {
                if isComplete {
                    self.stop(reason: .exception(.remoteComplete))
                    Logger.general.warn(category: "DeviceTransferClient", message: "Remote closed")
                }
                return
            }
            
            if let header = message[DeviceTransferProtocol.MessageKey.header] as? DeviceTransferHeader {
                switch header.type {
                case .command:
                    self.handleCommand(content: content)
                case .message:
                    self.handleMessage(content: content)
                case .file:
                    // File is delivered with `DeviceTransferProtocol.FileContext`
                    // See `DeviceTransferProtocol` for details
                    assertionFailure()
                }
            } else if let context = message[DeviceTransferProtocol.MessageKey.fileContext] as? DeviceTransferProtocol.FileContext {
                self.receiveFile(context: context, content: content)
            } else {
                Logger.general.warn(category: "DeviceTransferClient", message: "Protocol provides unknown context")
            }
            if let error {
                Logger.general.error(category: "DeviceTransferClient", message: "Error receiving message: \(error)")
            } else {
                self.continueReceiving(connection: connection)
            }
        }
    }
    
    private func handleCommand(content: Data) {
        assert(queue.isCurrent)
        let firstHMACIndex = content.endIndex.advanced(by: -DeviceTransferProtocol.hmacDataCount)
        let encryptedData = content[..<firstHMACIndex]
        let localHMAC = HMACSHA256.mac(for: encryptedData, using: key.hmac)
        let remoteHMAC = content[firstHMACIndex...]
        guard localHMAC == remoteHMAC else {
            stop(reason: .exception(.mismatchedHMAC(local: localHMAC, remote: remoteHMAC)))
            return
        }
        
        let command: DeviceTransferCommand
        do {
            let decryptedData = try AESCryptor.decrypt(encryptedData, with: key.aes)
            command = try JSONDecoder.default.decode(DeviceTransferCommand.self, from: decryptedData)
        } catch {
            Logger.general.error(category: "DeviceTransferClient", message: "Unable to decode message: \(error)")
            return
        }
        
        switch command.action {
        case .start(let count):
            Logger.general.info(category: "DeviceTransferClient", message: "Total count: \(count)")
            self.state = .transfer(progress: 0, speed: "")
            DispatchQueue.main.async {
                self.dataWriter.canProcessData = true
                self.totalCount = count
                self.startUpdatingProgressAndSpeed()
            }
        case .finish:
            Logger.general.info(category: "DeviceTransferClient", message: "Received finish command")
            do {
                let command = DeviceTransferCommand(action: .finish)
                let content = try DeviceTransferProtocol.output(command: command, key: key)
                self.connection.send(content: content, isComplete: true, completion: .idempotent)
                Logger.general.info(category: "DeviceTransferClient", message: "Sent finish command")
            } catch {
                Logger.general.error(category: "DeviceTransferClient", message: "Failed to finish command: \(error)")
            }
            DispatchQueue.main.async {
                self.dataWriter.delegate = self
            }
            dataWriter.transferFinished()
            self.stop(reason: .finished)
        default:
            break
        }
    }
    
    private func handleMessage(content: Data) {
        assert(queue.isCurrent)
        DispatchQueue.main.sync {
            speedInspector.add(byteCount: content.count)
            processedCount += 1
        }
        
        let firstHMACIndex = content.endIndex.advanced(by: -DeviceTransferProtocol.hmacDataCount)
        let encryptedData = content[..<firstHMACIndex]
        let localHMAC = HMACSHA256.mac(for: encryptedData, using: key.hmac)
        let remoteHMAC = content[firstHMACIndex...]
        guard localHMAC == remoteHMAC else {
            stop(reason: .exception(.mismatchedHMAC(local: localHMAC, remote: remoteHMAC)))
            return
        }
        do {
            let decryptedData = try AESCryptor.decrypt(encryptedData, with: key.aes)
            if !dataWriter.write(data: decryptedData) {
                stop(reason: .exception(.unableSaveData))
            }
        } catch {
            Logger.general.error(category: "DeviceTransferClient", message: "Unable to decrypt: \(error)")
            return
        }
    }
    
    private func receiveFile(context: DeviceTransferProtocol.FileContext, content: Data) {
        assert(queue.isCurrent)
        
        // File is received in slices, managed by the argument of `context`
        let isReceivingNewFile: Bool
        let stream: DeviceTransferFileStream
        if let currentStream = self.fileStream {
            if currentStream.id == context.fileHeader.id {
                stream = currentStream
                isReceivingNewFile = false
            } else {
                assertionFailure("Should be closed by the end of previous call")
                do {
                    try currentStream.close()
                } catch let DeviceTransferError.mismatchedHMAC(local, remote) {
                    stop(reason: .exception(.mismatchedHMAC(local: local, remote: remote)))
                } catch {
                    stop(reason: .exception(.failed(error)))
                }
                stream = DeviceTransferFileStream(context: context, key: key)
                isReceivingNewFile = true
            }
        } else {
            stream = DeviceTransferFileStream(context: context, key: key)
            isReceivingNewFile = true
        }
        if isReceivingNewFile {
            self.fileStream = stream
        }
        
        DispatchQueue.main.sync {
            speedInspector.add(byteCount: content.count)
            if isReceivingNewFile {
                processedCount += 1
            }
        }
        
        do {
            try stream.write(data: content)
        } catch {
            Logger.general.error(category: "DeviceTransferClient", message: "Failed to write: \(error)")
            stop(reason: .exception(.receiveFile(error)))
        }
        if context.remainingLength == 0 {
            do {
                try stream.close()
            } catch let DeviceTransferError.mismatchedHMAC(local, remote) {
                stop(reason: .exception(.mismatchedHMAC(local: local, remote: remote)))
            } catch {
                stop(reason: .exception(.failed(error)))
            }
            self.fileStream = nil
        }
    }
    
}

extension DeviceTransferClient: DeviceTransferDataWriterDelegate {
    
    func deviceTransferDataWriter(_ writer: DeviceTransferDataWriter, update progress: Float) {
        if progress >= 1 {
            Logger.general.info(category: "DeviceTransferClient", message: "Import finished")
            ConversationDAO.shared.updateLastMessageIdAndCreatedAt()
            state = .finished
        } else {
            state = .importing(progress: progress)
        }
    }
    
}
