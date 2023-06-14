import Foundation
import Network
import Combine
import MixinServices

final class DeviceTransferClient {
    
    enum State {
        case idle
        case transfer(progress: Float, speed: String) // `progress` is between 0.0 and 1.0
        case failed(DeviceTransferError)
        case importing(progress: Float) // `progress` is between 0.0 and 1.0
        case finished
    }
    
    @Published private(set) var state: State = .idle
    
    private let hostname: String
    private let port: UInt16
    private let code: UInt16
    private let key: DeviceTransferKey
    private let remotePlatform: DeviceTransferPlatform
    private let connection: NWConnection
    private let cacheContainerURL: URL
    private let messageProcessor: DeviceTransferMessageProcessor
    private let queue = Queue(label: "one.mixin.messenger.DeviceTransferClient")
    private let speedInspector = NetworkSpeedInspector()
    
    private weak var statisticsTimer: Timer?
    
    private var fileStream: DeviceTransferFileStream?
    private var messageProcessingObservers: Set<AnyCancellable> = []
    
    // Access on main queue
    private var progress = DeviceTransferProgress()
    
    private var opaquePointer: UnsafeMutableRawPointer {
        Unmanaged<DeviceTransferClient>.passUnretained(self).toOpaque()
    }
    
    init(hostname: String, port: UInt16, code: UInt16, key: DeviceTransferKey, remotePlatform: DeviceTransferPlatform) throws {
        // https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileSystemOverview/FileSystemOverview.html#//apple_ref/doc/uid/TP40010672-CH2-SW2
        // In iOS 5.0 and later, the system may delete the Caches directory on rare occasions when the system is very low on disk space.
        // This will never occur while an app is running.
        let manager = FileManager.default
        let cacheContainerURL = try manager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("DeviceTransfer")
        if manager.fileExists(atPath: cacheContainerURL.path) {
            try? manager.removeItem(at: cacheContainerURL)
        }
        try manager.createDirectory(at: cacheContainerURL, withIntermediateDirectories: true)
        
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
        self.cacheContainerURL = cacheContainerURL
        self.messageProcessor = .init(key: key.aes,
                                      remotePlatform: remotePlatform,
                                      cacheContainerURL: cacheContainerURL,
                                      inputQueue: queue)
        Logger.general.info(category: "DeviceTransferClient", message: "\(opaquePointer) init")
    }
    
    deinit {
        Logger.general.info(category: "DeviceTransferClient", message: "\(opaquePointer) deinit")
    }
    
    func start() {
        Logger.general.info(category: "DeviceTransferClient", message: "Will start connecting to [\(hostname)]:\(port)")
        messageProcessor.$processingError
            .receive(on: queue.dispatchQueue)
            .sink { error in
                if let error {
                    self.fail(error: .importing(error))
                }
            }
            .store(in: &messageProcessingObservers)
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
                    self.fail(error: .connectionFailed(error))
                }
            case .cancelled:
                Logger.general.info(category: "DeviceTransferClient", message: "Connection cancelled")
            @unknown default:
                break
            }
        }
        connection.start(queue: queue.dispatchQueue)
    }
    
    private func fail(error: DeviceTransferError) {
        assert(queue.isCurrent)
        Logger.general.info(category: "DeviceTransferClient", message: "Failed: \(error), progress: \(progress)")
        DispatchQueue.main.sync {
            self.statisticsTimer?.invalidate()
        }
        connection.cancel()
        messageProcessingObservers.forEach { $0.cancel() }
        messageProcessingObservers.removeAll()
        messageProcessor.cancel()
        try? FileManager.default.removeItem(at: cacheContainerURL)
        Logger.general.info(category: "DeviceTransferClient", message: "Cache container removed")
        state = .failed(error)
    }
    
    private func startUpdatingStatistics() {
        assert(Queue.main.isCurrent)
        statisticsTimer?.invalidate()
        statisticsTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                Logger.general.warn(category: "DeviceTransferClient", message: "Statistic timer fired after self deinited")
                return
            }
            let speed = self.speedInspector.drain()
            let progress = self.progress.fractionCompleted
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
                    if case .transfer = self.state {
                        self.fail(error: .remoteComplete)
                    }
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
            fail(error: .mismatchedHMAC(local: localHMAC, remote: remoteHMAC))
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
                self.progress.totalUnitCount = count
                self.startUpdatingStatistics()
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
            messageProcessor.$progress
                .receive(on: queue.dispatchQueue)
                .sink { progress in
                    if progress == 1 {
                        Logger.general.info(category: "DeviceTransferClient", message: "Import finished")
                        ConversationDAO.shared.updateLastMessageIdAndCreatedAt()
                        try? FileManager.default.removeItem(at: self.cacheContainerURL)
                        Logger.general.info(category: "DeviceTransferClient", message: "Cache container removed")
                        DispatchQueue.main.sync {
                            self.statisticsTimer?.invalidate()
                        }
                        self.state = .finished
                    } else {
                        self.state = .importing(progress: progress)
                    }
                }
                .store(in: &messageProcessingObservers)
            messageProcessor.finishProcessing()
        default:
            break
        }
    }
    
    private func handleMessage(content: Data) {
        assert(queue.isCurrent)
        DispatchQueue.main.sync {
            speedInspector.add(byteCount: content.count)
            progress.completedUnitCount += 1
        }
        
        let firstHMACIndex = content.endIndex.advanced(by: -DeviceTransferProtocol.hmacDataCount)
        let encryptedData = content[..<firstHMACIndex]
        let localHMAC = HMACSHA256.mac(for: encryptedData, using: key.hmac)
        let remoteHMAC = content[firstHMACIndex...]
        guard localHMAC == remoteHMAC else {
            fail(error: .mismatchedHMAC(local: localHMAC, remote: remoteHMAC))
            return
        }
        do {
            try messageProcessor.process(encryptedMessage: encryptedData)
        } catch {
            Logger.general.error(category: "DeviceTransferClient", message: "Handle message: \(error)")
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
                } catch let error as DeviceTransferError {
                    fail(error: error)
                } catch {
                    fail(error: .receiveFile(error))
                }
                stream = .init(context: context, key: key, containerURL: cacheContainerURL)
                isReceivingNewFile = true
            }
        } else {
            stream = .init(context: context, key: key, containerURL: cacheContainerURL)
            isReceivingNewFile = true
        }
        if isReceivingNewFile {
            self.fileStream = stream
        }
        
        DispatchQueue.main.sync {
            speedInspector.add(byteCount: content.count)
            if isReceivingNewFile {
                progress.completedUnitCount += 1
            }
        }
        
        do {
            try stream.write(data: content)
        } catch {
            Logger.general.error(category: "DeviceTransferClient", message: "Failed to write: \(error)")
            fail(error: .receiveFile(error))
        }
        if context.remainingLength == 0 {
            do {
                try stream.close()
            } catch let error as DeviceTransferError {
                fail(error: error)
            } catch {
                fail(error: .receiveFile(error))
            }
            self.fileStream = nil
            messageProcessor.reportFileReceived()
        }
    }
    
}
