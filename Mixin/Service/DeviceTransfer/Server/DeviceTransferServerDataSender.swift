import Foundation
import MixinServices

class DeviceTransferServerDataSender {
    
    weak var server: DeviceTransferServer?
    
    private let limit = 100
    private let fileBufferSize = 1024 * 1024 * 10
    private let maxConcurrentSends = 1000
    
    init(server: DeviceTransferServer) {
        self.server = server
    }
    
    func startTransfer() {
        DispatchQueue.global().async {
            self.sendStartCommand()
            DeviceTransferMessageType.allCases.forEach(self.sendTransferItems(type:))
            self.sendAttachments()
            self.sendFinishCommand()
        }
    }
    
}

extension DeviceTransferServerDataSender {
    
    private func sendStartCommand() {
        let messagesCount = MessageDAO.shared.messagesCount()
        let attachmentsCount = attachmentsCount()
        let total = ConversationDAO.shared.conversationsCount()
            + ParticipantDAO.shared.participantsCount()
            + UserDAO.shared.usersCount()
            + AppDAO.shared.appsCount()
            + AssetDAO.shared.assetsCount()
            + SnapshotDAO.shared.snapshotsCount()
            + StickerDAO.shared.stickersCount()
            + PinMessageDAO.shared.pinMessagesCount()
            + TranscriptMessageDAO.shared.transcriptMessagesCount()
            + messagesCount
            + MessageMentionDAO.shared.messageMentionsCount()
            + ExpiredMessageDAO.shared.expiredMessagesCount()
            + attachmentsCount
        Logger.general.info(category: "DeviceTransferServerDataSender", message: "Total: \(total), Messages: \(messagesCount), attachments: \(attachmentsCount)")
        let command = DeviceTransferCommand(action: .start, total: total)
        if let server, let commandData = server.composer.commandData(command: command) {
            Logger.general.info(category: "DeviceTransferServerDataSender", message: "Send Start Command")
            server.send(data: commandData)
            server.displayState = .transporting(processedCount: 0, totalCount: total)
        }
    }
    
    private func sendFinishCommand() {
        let command = DeviceTransferCommand(action: .finish)
        if let server, let data = server.composer.commandData(command: command) {
            Logger.general.info(category: "DeviceTransferServerDataSender", message: "Send Finish Command")
            server.send(data: data)
        }
    }
    
    private func sendTransferItems(type: DeviceTransferMessageType) {
        guard type != .unknown else {
            return
        }
        Logger.general.info(category: "DeviceTransferServerDataSender", message: "Send \(type)")
        var offset = 0
        var lastMessageId: String?
        let semaphore = DispatchSemaphore(value: maxConcurrentSends)
        while let server, server.canSendData {
            let transferItems: [Codable]
            switch type {
            case .conversation:
                transferItems = ConversationDAO.shared.conversations(limit: limit, offset: offset)
                    .map { conversation in
                        DeviceTransferConversation(conversation: conversation, to: server.connectionCommand?.platform)
                    }
            case .participant:
                transferItems = ParticipantDAO.shared.participants(limit: limit, offset: offset)
                    .map { DeviceTransferParticipant(participant: $0) }
            case .user:
                transferItems = UserDAO.shared.users(limit: limit, offset: offset)
                    .map { DeviceTransferUser(user: $0) }
            case .app:
                transferItems = AppDAO.shared.apps(limit: limit, offset: offset)
                    .map { DeviceTransferApp(app: $0) }
            case .asset:
                transferItems = AssetDAO.shared.assets(limit: limit, offset: offset)
                    .map { DeviceTransferAsset(asset: $0) }
            case .snapshot:
                transferItems = SnapshotDAO.shared.snapshots(limit: limit, offset: offset)
                    .map { DeviceTransferSnapshot(snapshot: $0) }
            case .sticker:
                transferItems = StickerDAO.shared.stickers(limit: limit, offset: offset)
                    .map { DeviceTransferSticker(sticker: $0) }
            case .pinMessage:
                transferItems = PinMessageDAO.shared.pinMessages(limit: limit, offset: offset)
                    .map { DeviceTransferPinMessage(pinMessage: $0) }
            case .transcriptMessage:
                transferItems = TranscriptMessageDAO.shared.transcriptMessages(limit: limit, offset: offset)
                    .map { DeviceTransferTranscriptMessage(transcriptMessage: $0) }
            case .message:
                let messages = MessageDAO.shared.messages(limit: limit, after: lastMessageId)
                lastMessageId = messages.last?.messageId
                transferItems = messages.map { DeviceTransferMessage(message: $0) }
            case .messageMention:
                transferItems = MessageMentionDAO.shared.messageMentions(limit: limit, offset: offset)
                    .map { DeviceTransferMessageMention(messageMention: $0) }
            case .expiredMessage:
                transferItems = ExpiredMessageDAO.shared.expiredMessages(limit: limit, offset: offset)
                    .map { DeviceTransferExpiredMessage(expiredMessage: $0) }
            case .unknown:
                return
            }
            if transferItems.isEmpty {
                return
            }
            let itemData = transferItems.compactMap { server.composer.messageData(type: type, data: $0) }
            for data in itemData {
                semaphore.wait()
                server.send(data: data) {
                    semaphore.signal()
                }
            }
            if transferItems.count < limit {
                return
            }
            offset += limit
        }
    }
    
    private func sendAttachments() {
        let types = AttachmentContainer.Category.allCases.map(\.pathComponent) + ["Transcript"]
        types.forEach(sendAttachment(type:))
    }
    
}

extension DeviceTransferServerDataSender {
    
    private func sendAttachment(type: String) {
        let fileDirectory = AttachmentContainer.url.appendingPathComponent(type)
        let allFilePaths = getAllFilePaths(inDirectory: fileDirectory)
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: fileBufferSize)
        defer {
            buffer.deallocate()
        }
        Logger.general.info(category: "DeviceTransferServerDataSender", message: "Send \(type) \(allFilePaths.count)")
        for path in allFilePaths {
            guard let server, server.canSendData else {
                break
            }
            let components = path.lastPathComponent.components(separatedBy: ".")
            guard components.count == 2, let idData = UUID(uuidString: components[0])?.data else {
                continue
            }
            guard let stream = InputStream(url: path) else {
                Logger.general.info(category: "DeviceTransferServerDataSender", message: "Open stream failed")
                continue
            }
            Logger.general.info(category: "DeviceTransferServerDataSender", message: "Send File: \(path.absoluteString)")
            // send typeData + lengthData + idData
            var checksum = CRC32()
            let fileSize = Int(FileManager.default.fileSize(path.path))
            let typeData = Data([DeviceTransferDataType.file.rawValue])
            let lengthData = UInt32(idData.count + fileSize).data(endianness: .big)
            let header = typeData + lengthData + idData
            checksum.update(data: idData)
            server.send(data: header)
            // send content data
            stream.open()
            let semaphore = DispatchSemaphore(value: 1)
            while stream.hasBytesAvailable {
                let bytesRead = stream.read(buffer, maxLength: fileBufferSize)
                if bytesRead < 0 {
                    if let error = stream.streamError {
                        Logger.general.info(category: "DeviceTransferServerDataSender", message: "Read stream failed:\(error)")
                    }
                    break
                }
                let data = Data(bytesNoCopy: buffer, count: bytesRead, deallocator: .none)
                checksum.update(data: data)
                semaphore.wait()
                server.send(data: data) {
                    semaphore.signal()
                }
            }
            stream.close()
            // send checksum data
            let checksumData = checksum.finalize().data(endianness: .big)
            server.send(data: checksumData)
        }
    }
    
    private func getAllFilePaths(inDirectory url: URL) -> [URL] {
        var filePaths: [URL] = []
        guard let fileEnumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return filePaths
        }
        for case let fileURL as URL in fileEnumerator {
            // filter thumb
            if url.lastPathComponent == AttachmentContainer.Category.videos.pathComponent, fileURL.lastPathComponent.contains(ExtensionName.jpeg.withDot)  {
                continue
            }
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if let isRegularFile = resourceValues.isRegularFile, isRegularFile {
                    filePaths.append(fileURL)
                }
            } catch {
                Logger.general.info(category: "DeviceTransferServerDataSender", message: "Failed to get file path: \(error)")
            }
        }
        return filePaths
    }
    
    private func attachmentsCount() -> Int {
        var count = 0
        let types = AttachmentContainer.Category.allCases.map(\.pathComponent) + ["Transcript"]
        for type in types {
            let fileDirectory = AttachmentContainer.url.appendingPathComponent(type)
            let allFilePaths = getAllFilePaths(inDirectory: fileDirectory)
            count += allFilePaths.count
        }
        return count
    }
    
}
