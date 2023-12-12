import Foundation
import Network
import MixinServices

final class DeviceTransferClient {
    
    enum State {
        case idle
        case transfer(progress: Double, speed: String)
        case closed(DeviceTransferClosedReason)
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
    
    private func stop(reason: DeviceTransferClosedReason) {
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
                self.totalCount = count
                self.startUpdatingProgressAndSpeed()
            }
        case .finish:
            Logger.general.info(category: "DeviceTransferClient", message: "Received finish command")
            ConversationDAO.shared.updateLastMessageIdAndCreatedAt()
            do {
                let command = DeviceTransferCommand(action: .finish)
                let content = try DeviceTransferProtocol.output(command: command, key: key)
                self.connection.send(content: content, isComplete: true, completion: .idempotent)
                Logger.general.info(category: "DeviceTransferClient", message: "Sent finish command")
            } catch {
                Logger.general.error(category: "DeviceTransferClient", message: "Failed to finish command: \(error)")
            }
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
        
        let decryptedData: Data
        do {
            decryptedData = try AESCryptor.decrypt(encryptedData, with: key.aes)
        } catch {
            Logger.general.error(category: "DeviceTransferClient", message: "Unable to decrypt: \(error)")
            return
        }
        
        do {
            struct TypeWrapper: Decodable {
                let type: DeviceTransferRecordType
            }
            
            let decoder = JSONDecoder.default
            let wrapper = try decoder.decode(TypeWrapper.self, from: decryptedData)
            switch wrapper.type {
            case .conversation:
                let conversation = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferConversation>.self, from: decryptedData).data
                ConversationDAO.shared.save(conversation: conversation.toConversation(from: remotePlatform))
            case .participant:
                let participant = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferParticipant>.self, from: decryptedData).data
                ParticipantDAO.shared.save(participant: participant.toParticipant())
            case .user:
                let user = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferUser>.self, from: decryptedData).data
                UserDAO.shared.save(user: user.toUser())
            case .app:
                let app = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferApp>.self, from: decryptedData).data
                AppDAO.shared.save(app: app.toApp())
            case .asset:
                let asset = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferAsset>.self, from: decryptedData).data
                AssetDAO.shared.save(asset: asset.toAsset())
            case .token:
                let token = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferToken>.self, from: decryptedData).data
                TokenDAO.shared.save(token: token.toToken())
            case .snapshot:
                let snapshot = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferSnapshot>.self, from: decryptedData).data
                SnapshotDAO.shared.save(snapshot: snapshot.toSnapshot())
            case .safe_snapshot:
                let safeSnapshot = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferSafeSnapshot>.self, from: decryptedData).data
                SafeSnapshotDAO.shared.save(snapshot: safeSnapshot.toSafeSnapshot(), postChangeNotification: false)
            case .sticker:
                let sticker = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferSticker>.self, from: decryptedData).data
                StickerDAO.shared.save(sticker: sticker.toSticker())
            case .pinMessage:
                let pinMessage = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferPinMessage>.self, from: decryptedData).data
                PinMessageDAO.shared.save(pinMessage: pinMessage.toPinMessage())
            case .transcriptMessage:
                let transcriptMessage = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferTranscriptMessage>.self, from: decryptedData).data
                TranscriptMessageDAO.shared.save(transcriptMessage: transcriptMessage.toTranscriptMessage())
            case .message:
                let message = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferMessage>.self, from: decryptedData).data
                if MessageCategory.isLegal(category: message.category) {
                    MessageDAO.shared.save(message: message.toMessage())
                } else {
                    Logger.general.warn(category: "DeviceTransferClient", message: "Message is illegal: \(message)")
                }
            case .messageMention:
                let messageMention = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferMessageMention>.self, from: decryptedData).data
                if let mention = messageMention.toMessageMention() {
                    MessageMentionDAO.shared.save(messageMention: mention)
                } else {
                    Logger.general.warn(category: "DeviceTransferClient", message: "Message Mention does not exist: \(messageMention)")
                }
            case .expiredMessage:
                let expiredMessage = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferExpiredMessage>.self, from: decryptedData).data
                ExpiredMessageDAO.shared.save(expiredMessage: expiredMessage.toExpiredMessage())
            }
        } catch {
            let content = String(data: decryptedData, encoding: .utf8) ?? "Data(\(decryptedData.count))"
            Logger.general.error(category: "DeviceTransferClient", message: "Error: \(error) Content: \(content)")
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
                currentStream.close()
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
            stream.close()
            self.fileStream = nil
        }
    }
    
}
