import Foundation
import MixinServices

class DeviceTransferServerDataSender {
    
    weak var server: DeviceTransferServer?
    
    private let limit = 100
    private let fileBufferSize = 1024 * 1024 * 10
    private let maxWaitingTime: TimeInterval = 10.0

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
        } else {
            Logger.general.info(category: "DeviceTransferServerDataSender", message: "Compose start command data failed")
        }
    }
    
    private func sendFinishCommand() {
        guard let server, server.canSendData else {
            let message = server == nil ? "Server is nil" : "Server can't send data"
            Logger.general.info(category: "DeviceTransferServerDataSender", message: "\(message) when sending finish command")
            return
        }
        let command = DeviceTransferCommand(action: .finish)
        if let data = server.composer.commandData(command: command) {
            Logger.general.info(category: "DeviceTransferServerDataSender", message: "Send Finish Command")
            server.send(data: data)
        } else {
            Logger.general.info(category: "DeviceTransferServerDataSender", message: "Compose finish command data failed")
        }
    }
    
    private func sendTransferItems(type: DeviceTransferMessageType) {
        guard type != .unknown else {
            return
        }
        guard let server, server.canSendData else {
            let message = server == nil ? "Server is nil" : "Server can't send data"
            Logger.general.info(category: "DeviceTransferServerDataSender", message: "\(message) when sending \(type)")
            return
        }
        Logger.general.info(category: "DeviceTransferServerDataSender", message: "Send \(type)")
        var lastItemId: String?
        var lastItemAssistanceId: String?
        let semaphore = DispatchSemaphore(value: 1)
        while server.canSendData {
            let transferItems: [Codable]
            switch type {
            case .conversation:
                let conversations = ConversationDAO.shared.conversations(limit: limit, after: lastItemId)
                lastItemId = conversations.last?.conversationId
                transferItems = conversations.map { conversation in
                    DeviceTransferConversation(conversation: conversation, to: server.connectionCommand?.platform)
                }
            case .participant:
                let participants = ParticipantDAO.shared.participants(limit: limit, after: lastItemId, with: lastItemAssistanceId)
                lastItemId = participants.last?.conversationId
                lastItemAssistanceId = participants.last?.userId
                transferItems = participants.map { DeviceTransferParticipant(participant: $0) }
            case .user:
                let users = UserDAO.shared.users(limit: limit, after: lastItemId)
                lastItemId = users.last?.userId
                transferItems = users.map { DeviceTransferUser(user: $0) }
            case .app:
                let apps = AppDAO.shared.apps(limit: limit, after: lastItemId)
                lastItemId = apps.last?.appId
                transferItems = apps.map { DeviceTransferApp(app: $0) }
            case .asset:
                let assets = AssetDAO.shared.assets(limit: limit, after: lastItemId)
                lastItemId = assets.last?.assetId
                transferItems = assets.map { DeviceTransferAsset(asset: $0) }
            case .snapshot:
                let snapshots = SnapshotDAO.shared.snapshots(limit: limit, after: lastItemId)
                lastItemId = snapshots.last?.snapshotId
                transferItems = snapshots.map { DeviceTransferSnapshot(snapshot: $0) }
            case .sticker:
                let stickers = StickerDAO.shared.stickers(limit: limit, after: lastItemId)
                lastItemId = stickers.last?.stickerId
                transferItems = stickers.map { DeviceTransferSticker(sticker: $0) }
            case .pinMessage:
                let pinMessages = PinMessageDAO.shared.pinMessages(limit: limit, after: lastItemId)
                lastItemId = pinMessages.last?.messageId
                transferItems = pinMessages.map { DeviceTransferPinMessage(pinMessage: $0) }
            case .transcriptMessage:
                let transcriptMessages = TranscriptMessageDAO.shared.transcriptMessages(limit: limit, after: lastItemId, with: lastItemAssistanceId)
                lastItemId = transcriptMessages.last?.transcriptId
                lastItemAssistanceId = transcriptMessages.last?.messageId
                transferItems = transcriptMessages.map { DeviceTransferTranscriptMessage(transcriptMessage: $0) }
            case .message:
                let messages = MessageDAO.shared.messages(limit: limit, after: lastItemId)
                lastItemId = messages.last?.messageId
                transferItems = messages.map { DeviceTransferMessage(message: $0) }
            case .messageMention:
                let messageMentions = MessageMentionDAO.shared.messageMentions(limit: limit, after: lastItemId)
                lastItemId = messageMentions.last?.messageId
                transferItems = messageMentions.map { DeviceTransferMessageMention(messageMention: $0) }
            case .expiredMessage:
                let expiredMessages = ExpiredMessageDAO.shared.expiredMessages(limit: limit, after: lastItemId)
                lastItemId = expiredMessages.last?.messageId
                transferItems = expiredMessages.map { DeviceTransferExpiredMessage(expiredMessage: $0) }
            case .unknown:
                return
            }
            if transferItems.isEmpty {
                Logger.general.info(category: "DeviceTransferServerDataSender", message: "\(type) is empty")
                return
            }
            let itemData = transferItems.compactMap { server.composer.messageData(type: type, data: $0) }
            for (index, data) in itemData.enumerated() {
                let result = semaphore.wait(timeout: .now() + maxWaitingTime)
                if result == .timedOut {
                    Logger.general.info(category: "DeviceTransferServerDataSender", message: "\(type) data sending timed out. Quantities equal:\(transferItems.count == itemData.count). DataCount: \(data.count). Item: \(String(describing: transferItems[index])) CanSendData: \(server.canSendData)")
                    server.collectReport(reason: "\(type) data sending timed out: \(String(describing: transferItems[index]))")
                }
                server.send(data: data) {
                    semaphore.signal()
                }
            }
            Logger.general.info(category: "DeviceTransferServerDataSender", message: "Send \(type) \(transferItems.count). CanSendData: \(server.canSendData)")
            if transferItems.count < limit {
                return
            }
        }
    }
    
    private func sendAttachments() {
        guard let server, server.canSendData else {
            let message = server == nil ? "Server is nil" : "Server can't send data"
            Logger.general.info(category: "DeviceTransferServerDataSender", message: "\(message) when sending attachments")
            return
        }
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
            guard components.count == 2, let fileMessageId = components.first, let idData = UUID(uuidString: fileMessageId)?.data else {
                continue
            }
            guard MessageDAO.shared.hasMessage(id: fileMessageId) || TranscriptMessageDAO.shared.hasTranscriptMessage(withMessageId: fileMessageId) else {
                Logger.general.info(category: "DeviceTransferServerDataSender", message: "Message not exists for attachment: \(path)")
                try? FileManager.default.removeItem(at: path)
                continue
            }
            guard let stream = InputStream(url: path) else {
                Logger.general.info(category: "DeviceTransferServerDataSender", message: "Open stream failed")
                continue
            }
            Logger.general.debug(category: "DeviceTransferServerDataSender", message: "Send File: \(path.absoluteString)")
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
                guard bytesRead > 0 else {
                    if let error = stream.streamError {
                        Logger.general.info(category: "DeviceTransferServerDataSender", message: "Read stream failed: \(error)")
                    }
                    break
                }
                let data = Data(bytes: buffer, count: bytesRead)
                checksum.update(data: data)
                let result = semaphore.wait(timeout: .now() + maxWaitingTime)
                if result == .timedOut {
                    Logger.general.info(category: "DeviceTransferServerDataSender", message: "File sending timed out \(path). DataCount: \(data.count). CanSendData: \(server.canSendData)")
                    server.collectReport(reason: "File sending timed out \(path)")
                }
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
