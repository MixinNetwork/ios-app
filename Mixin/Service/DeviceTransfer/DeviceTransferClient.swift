import Foundation
import Network
import MixinServices

final class DeviceTransferClient {
    
    enum State {
        case idle
        case connecting
        case transfer(progress: Double, speed: String)
        case closed(DeviceTransferClosedReason)
    }
    
    @Published private(set) var state: State = .idle
    
    private let hostname: String
    private let port: UInt16
    private let code: UInt16
    private let remotePlatform: DeviceTransferPlatform
    private let connection: NWConnection
    private let queue = Queue(label: "one.mixin.messenger.DeviceTransferClient")
    private let speedInspector = NetworkSpeedInspector()
    
    private weak var timer: Timer?
    
    private var fileStream: DeviceTransferFileStream?
    
    // Access counts on main queue
    private var processedCount = 0
    private var totalCount: Int?
    
    init(hostname: String, port: UInt16, code: UInt16, remotePlatform: DeviceTransferPlatform) {
        self.hostname = hostname
        self.port = port
        self.code = code
        self.remotePlatform = remotePlatform
        self.connection = {
            let host = NWEndpoint.Host(hostname)
            let port = NWEndpoint.Port(integerLiteral: port)
            let endpoint = NWEndpoint.hostPort(host: host, port: port)
            return NWConnection(to: endpoint, using: .deviceTransfer)
        }()
        Logger.general.info(category: "DeviceTransferClient", message: "\(Unmanaged<DeviceTransferClient>.passUnretained(self).toOpaque()) init")
    }
    
    deinit {
        Logger.general.info(category: "DeviceTransferClient", message: "\(Unmanaged<DeviceTransferClient>.passUnretained(self).toOpaque()) deinit")
    }
    
    func start() {
        Logger.general.info(category: "DeviceTransferClient", message: "Will start connecting to [\(hostname)]:\(port)")
        connection.stateUpdateHandler = { [weak self, unowned connection, code] state in
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
                    self.continueReceiving(connection: connection)
                    let connect = DeviceTransferCommand(action: .connect(code: code, userID: myUserId))
                    if let content = DeviceTransferProtocol.output(command: connect) {
                        Logger.general.info(category: "DeviceTransferClient", message: "Send connect command: \(connect)")
                        connection.send(content: content, completion: .idempotent)
                    }
                } else {
                    Logger.general.error(category: "DeviceTransferClient", message: "Connection ready after self deinited")
                }
            case .failed(let error):
                Logger.general.warn(category: "DeviceTransferClient", message: "Failed: \(error)")
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
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            let speed = self.speedInspector.consume()
            let progress: Double
            if let totalCount = self.totalCount {
                progress = Double(self.processedCount) * 100 / Double(totalCount)
            } else {
                progress = 0
            }
            self.queue.async {
                guard case .transfer = self.state else {
                    DispatchQueue.main.sync(execute: timer.invalidate)
                    Logger.general.warn(category: "DeviceTransferClient", message: "Progress timer invalidated on firing")
                    return
                }
                self.state = .transfer(progress: progress, speed: speed)
                let command = DeviceTransferCommand(action: .progress(progress))
                if let content = DeviceTransferProtocol.output(command: command){
                    self.connection.send(content: content, completion: .idempotent)
                    Logger.general.info(category: "DeviceTransferClient", message: "Report progress: \(progress), speed: \(speed)")
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
                    self.state = .closed(.exception(.remoteComplete))
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
            if error == nil {
                self.continueReceiving(connection: connection)
            }
        }
    }
    
    private func handleCommand(content: Data) {
        assert(queue.isCurrent)
        let jsonData = content[..<content.endIndex.advanced(by: -8)]
        let localChecksum = CRC32.checksum(data: jsonData)
        let remoteChecksum = UInt64(data: content[content.endIndex.advanced(by: -8)...], endianess: .big)
        guard localChecksum == remoteChecksum else {
            stop(reason: .exception(.checksumError(local: localChecksum, remote: remoteChecksum)))
            return
        }
        let command: DeviceTransferCommand
        do {
            command = try JSONDecoder.default.decode(DeviceTransferCommand.self, from: jsonData)
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
            self.state = .closed(.finished)
            let command = DeviceTransferCommand(action: .finish)
            if let content = DeviceTransferProtocol.output(command: command){
                Logger.general.info(category: "DeviceTransferClient", message: "Send finish command")
                self.connection.send(content: content, isComplete: true, completion: .idempotent)
            }
        default:
            break
        }
    }
    
    private func handleMessage(content: Data) {
        assert(queue.isCurrent)
        DispatchQueue.main.sync {
            speedInspector.store(count: content.count)
            processedCount += 1
        }
        let jsonData = content[..<content.endIndex.advanced(by: -8)]
        let localChecksum = CRC32.checksum(data: jsonData)
        let remoteChecksum = UInt64(data: content[content.endIndex.advanced(by: -8)...], endianess: .big)
        guard localChecksum == remoteChecksum else {
            stop(reason: .exception(.checksumError(local: localChecksum, remote: remoteChecksum)))
            return
        }
        do {
            struct TypeWrapper: Decodable {
                let type: DeviceTransferRecordType
            }
            
            let decoder = JSONDecoder.default
            let wrapper = try decoder.decode(TypeWrapper.self, from: jsonData)
            switch wrapper.type {
            case .conversation:
                let conversation = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferConversation>.self, from: jsonData).data
                ConversationDAO.shared.save(conversation: conversation.toConversation(from: remotePlatform))
            case .participant:
                let participant = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferParticipant>.self, from: jsonData).data
                ParticipantDAO.shared.save(participant: participant.toParticipant())
            case .user:
                let user = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferUser>.self, from: jsonData).data
                UserDAO.shared.save(user: user.toUser())
            case .app:
                let app = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferApp>.self, from: jsonData).data
                AppDAO.shared.save(app: app.toApp())
            case .asset:
                let asset = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferAsset>.self, from: jsonData).data
                AssetDAO.shared.save(asset: asset.toAsset())
            case .snapshot:
                let snapshot = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferSnapshot>.self, from: jsonData).data
                SnapshotDAO.shared.save(snapshot: snapshot.toSnapshot())
            case .sticker:
                let sticker = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferSticker>.self, from: jsonData).data
                StickerDAO.shared.save(sticker: sticker.toSticker())
            case .pinMessage:
                let pinMessage = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferPinMessage>.self, from: jsonData).data
                PinMessageDAO.shared.save(pinMessage: pinMessage.toPinMessage())
            case .transcriptMessage:
                let transcriptMessage = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferTranscriptMessage>.self, from: jsonData).data
                TranscriptMessageDAO.shared.save(transcriptMessage: transcriptMessage.toTranscriptMessage())
            case .message:
                let message = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferMessage>.self, from: jsonData).data
                if MessageCategory.isLegal(category: message.category) {
                    MessageDAO.shared.save(message: message.toMessage())
                }
            case .messageMention:
                if let messageMention = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferMessageMention>.self, from: jsonData).data.toMessageMention() {
                    MessageMentionDAO.shared.save(messageMention: messageMention)
                }
            case .expiredMessage:
                let expiredMessage = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferExpiredMessage>.self, from: jsonData).data
                ExpiredMessageDAO.shared.save(expiredMessage: expiredMessage.toExpiredMessage())
            }
        } catch {
            let content = String(data: jsonData, encoding: .utf8) ?? "Data(\(jsonData.count))"
            Logger.general.error(category: "DeviceTransferClient", message: "Error: \(error) Content: \(content)")
        }
    }
    
    private func receiveFile(context: DeviceTransferProtocol.FileContext, content: Data) {
        assert(queue.isCurrent)
        
        // File is received in slices, managed by the argument of `context`
        let isReceivingNewFile: Bool
        let stream: DeviceTransferFileStream
        if let currentStream = self.fileStream {
            if currentStream.id == context.id {
                stream = currentStream
                isReceivingNewFile = false
            } else {
                currentStream.close()
                stream = DeviceTransferFileStream(context: context)
                isReceivingNewFile = true
            }
        } else {
            stream = DeviceTransferFileStream(context: context)
            isReceivingNewFile = true
        }
        if isReceivingNewFile {
            self.fileStream = stream
        }
        
        DispatchQueue.main.sync {
            speedInspector.store(count: content.count)
            if isReceivingNewFile {
                processedCount += 1
            }
        }
        
        stream.write(data: content)
        if context.remainingLength == 0 {
            stream.close()
            self.fileStream = nil
        }
    }
    
}
