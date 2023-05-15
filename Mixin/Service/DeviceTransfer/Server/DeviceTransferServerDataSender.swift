import Foundation
import MixinServices

class DeviceTransferServerDataSender {
    
    private struct TransferItem {
        let rawItem: Codable
        let messageData: Data
        let messageId: String?
        let attachmentPath: URL?
        
        init?(rawItem: Codable, messageData: Data?, messageId: String?, attachmentPath: URL?) {
            guard let messageData else {
                return nil
            }
            self.rawItem = rawItem
            self.messageData = messageData
            self.messageId = messageId
            self.attachmentPath = attachmentPath
        }
    }
    
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
            let transferItems: [TransferItem]
            switch type {
            case .conversation:
                let conversations = ConversationDAO.shared.conversations(limit: limit, after: lastItemId)
                lastItemId = conversations.last?.conversationId
                transferItems = conversations.compactMap { conversation in
                    let deviceTransferConversation = DeviceTransferConversation(conversation: conversation, to: server.connectionCommand?.platform)
                    let messageData = server.composer.messageData(type: type, data: deviceTransferConversation)
                    return TransferItem(rawItem: conversation, messageData: messageData, messageId: nil, attachmentPath: nil)
                }
            case .participant:
                let participants = ParticipantDAO.shared.participants(limit: limit, after: lastItemId, with: lastItemAssistanceId)
                lastItemId = participants.last?.conversationId
                lastItemAssistanceId = participants.last?.userId
                transferItems = participants.compactMap { participant in
                    let deviceTransferParticipant = DeviceTransferParticipant(participant: participant)
                    let messageData = server.composer.messageData(type: type, data: deviceTransferParticipant)
                    return TransferItem(rawItem: participant, messageData: messageData, messageId: nil, attachmentPath: nil)
                }
            case .user:
                let users = UserDAO.shared.users(limit: limit, after: lastItemId)
                lastItemId = users.last?.userId
                transferItems = users.compactMap { user in
                    let deviceTransferUser = DeviceTransferUser(user: user)
                    let messageData = server.composer.messageData(type: type, data: deviceTransferUser)
                    return TransferItem(rawItem: user, messageData: messageData, messageId: nil, attachmentPath: nil)
                }
            case .app:
                let apps = AppDAO.shared.apps(limit: limit, after: lastItemId)
                lastItemId = apps.last?.appId
                transferItems = apps.compactMap { app in
                    let deviceTransferApp = DeviceTransferApp(app: app)
                    let messageData = server.composer.messageData(type: type, data: deviceTransferApp)
                    return TransferItem(rawItem: app, messageData: messageData, messageId: nil, attachmentPath: nil)
                }
            case .asset:
                let assets = AssetDAO.shared.assets(limit: limit, after: lastItemId)
                lastItemId = assets.last?.assetId
                transferItems = assets.compactMap { asset in
                    let deviceTransferAsset = DeviceTransferAsset(asset: asset)
                    let messageData = server.composer.messageData(type: type, data: deviceTransferAsset)
                    return TransferItem(rawItem: asset, messageData: messageData, messageId: nil, attachmentPath: nil)
                }
            case .snapshot:
                let snapshots = SnapshotDAO.shared.snapshots(limit: limit, after: lastItemId)
                lastItemId = snapshots.last?.snapshotId
                transferItems = snapshots.compactMap { snapshot in
                    let deviceTransferSnapshot = DeviceTransferSnapshot(snapshot: snapshot)
                    let messageData = server.composer.messageData(type: type, data: deviceTransferSnapshot)
                    return TransferItem(rawItem: snapshot, messageData: messageData, messageId: nil, attachmentPath: nil)
                }
            case .sticker:
                let stickers = StickerDAO.shared.stickers(limit: limit, after: lastItemId)
                lastItemId = stickers.last?.stickerId
                transferItems = stickers.compactMap { sticker in
                    let deviceTransferSticker = DeviceTransferSticker(sticker: sticker)
                    let messageData = server.composer.messageData(type: type, data: deviceTransferSticker)
                    return TransferItem(rawItem: sticker, messageData: messageData, messageId: nil, attachmentPath: nil)
                }
            case .pinMessage:
                let pinMessages = PinMessageDAO.shared.pinMessages(limit: limit, after: lastItemId)
                lastItemId = pinMessages.last?.messageId
                transferItems = pinMessages.compactMap { pinMessage in
                    let deviceTransferPinMessage = DeviceTransferPinMessage(pinMessage: pinMessage)
                    let messageData = server.composer.messageData(type: type, data: deviceTransferPinMessage)
                    return TransferItem(rawItem: pinMessage, messageData: messageData, messageId: nil, attachmentPath: nil)
                }
            case .transcriptMessage:
                let transcriptMessages = TranscriptMessageDAO.shared.transcriptMessages(limit: limit, after: lastItemId, with: lastItemAssistanceId)
                lastItemId = transcriptMessages.last?.transcriptId
                lastItemAssistanceId = transcriptMessages.last?.messageId
                transferItems = transcriptMessages.compactMap { transcriptMessage in
                    let deviceTransferTranscriptMessage = DeviceTransferTranscriptMessage(transcriptMessage: transcriptMessage)
                    let messageData = server.composer.messageData(type: type, data: deviceTransferTranscriptMessage)
                    if let mediaURL = transcriptMessage.mediaUrl, !mediaURL.isEmpty {
                        let path = AttachmentContainer.url(transcriptId: transcriptMessage.transcriptId, filename: mediaURL)
                        return TransferItem(rawItem: transcriptMessage, messageData: messageData, messageId: transcriptMessage.messageId, attachmentPath: path)
                    } else {
                        return TransferItem(rawItem: transcriptMessage, messageData: messageData, messageId: nil, attachmentPath: nil)
                    }
                }
            case .message:
                let messages = MessageDAO.shared.messages(limit: limit, after: lastItemId)
                lastItemId = messages.last?.messageId
                transferItems = messages.compactMap { message in
                    let deviceTransferMessage = DeviceTransferMessage(message: message)
                    let messageData = server.composer.messageData(type: type, data: deviceTransferMessage)
                    if let mediaURL = message.mediaUrl, !mediaURL.isEmpty, let category = AttachmentContainer.Category(messageCategory: message.category) {
                        let path = AttachmentContainer.url(for: category, filename: mediaURL)
                        return TransferItem(rawItem: message, messageData: messageData, messageId: message.messageId, attachmentPath: path)
                    } else {
                        return TransferItem(rawItem: message, messageData: messageData, messageId: nil, attachmentPath: nil)
                    }
                }
            case .messageMention:
                let messageMentions = MessageMentionDAO.shared.messageMentions(limit: limit, after: lastItemId)
                lastItemId = messageMentions.last?.messageId
                transferItems = messageMentions.compactMap { messageMention in
                    let deviceTransferMessageMention = DeviceTransferMessageMention(messageMention: messageMention)
                    let messageData = server.composer.messageData(type: type, data: deviceTransferMessageMention)
                    return TransferItem(rawItem: messageMention, messageData: messageData, messageId: nil, attachmentPath: nil)
                }
            case .expiredMessage:
                let expiredMessages = ExpiredMessageDAO.shared.expiredMessages(limit: limit, after: lastItemId)
                lastItemId = expiredMessages.last?.messageId
                transferItems = expiredMessages.compactMap { expiredMessage in
                    let deviceTransferExpiredMessage = DeviceTransferExpiredMessage(expiredMessage: expiredMessage)
                    let messageData = server.composer.messageData(type: type, data: deviceTransferExpiredMessage)
                    return TransferItem(rawItem: expiredMessage, messageData: messageData, messageId: nil, attachmentPath: nil)
                }
            case .unknown:
                return
            }
            
            if transferItems.isEmpty {
                Logger.general.info(category: "DeviceTransferServerDataSender", message: "\(type) is empty")
                return
            }
            for item in transferItems {
                let result = semaphore.wait(timeout: .now() + maxWaitingTime)
                if result == .timedOut {
                    Logger.general.info(category: "DeviceTransferServerDataSender", message: "\(type) data sending timed out. CanSendData: \(server.canSendData). RawItem: \(item.rawItem)")
                    server.collectReport(reason: "\(type) sending timed out: \(item.rawItem)")
                }
                server.send(data: item.messageData) {
                    semaphore.signal()
                }
                sendAttachmentIfNeeded(transferItem: item)
            }
            Logger.general.info(category: "DeviceTransferServerDataSender", message: "Send \(type) \(transferItems.count). CanSendData: \(server.canSendData)")
            if transferItems.count < limit {
                return
            }
        }
    }
    
}

extension DeviceTransferServerDataSender {
    
    private func sendAttachmentIfNeeded(transferItem: TransferItem) {
        guard let messageId = transferItem.messageId, let attachmentPath = transferItem.attachmentPath else {
            return
        }
        guard let server, server.canSendData else {
            let message = server == nil ? "Server is nil" : "Server can't send data"
            Logger.general.info(category: "DeviceTransferServerDataSender", message: "\(message) when sending file: \(transferItem.rawItem)")
            return
        }
        guard let idData = UUID(uuidString: messageId)?.data else {
            Logger.general.info(category: "DeviceTransferServerDataSender", message: "Not valid messageId: \(messageId), raw: \(transferItem.rawItem)")
            return
        }
        guard let stream = InputStream(url: attachmentPath) else {
            Logger.general.info(category: "DeviceTransferServerDataSender", message: "Open stream failed: \(attachmentPath)")
            return
        }
        Logger.general.debug(category: "DeviceTransferServerDataSender", message: "Send File: \(attachmentPath.absoluteString)")
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: fileBufferSize)
        defer {
            buffer.deallocate()
        }
        // send typeData + lengthData + idData
        var checksum = CRC32()
        let fileSize = Int(FileManager.default.fileSize(attachmentPath.path))
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
                    Logger.general.info(category: "DeviceTransferServerDataSender", message: "Read stream failed: \(error), path: \(attachmentPath)")
                }
                break
            }
            let data = Data(bytes: buffer, count: bytesRead)
            checksum.update(data: data)
            let result = semaphore.wait(timeout: .now() + maxWaitingTime)
            if result == .timedOut {
                Logger.general.info(category: "DeviceTransferServerDataSender", message: "File sending timed out \(attachmentPath). FileSize: \(fileSize). CanSendData: \(server.canSendData) Raw: \(transferItem.rawItem)")
                server.collectReport(reason: "File sending timed out \(attachmentPath)")
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
    
    private func attachmentsCount() -> Int {
        var count = 0
        let types = AttachmentContainer.Category.allCases.map(\.pathComponent) + ["Transcript"]
        for type in types {
            let fileDirectory = AttachmentContainer.url.appendingPathComponent(type)
            count += validFileCount(inDirectory: fileDirectory)
        }
        return count
    }
    
    private func validFileCount(inDirectory url: URL) -> Int {
        var count = 0
        guard let fileEnumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return 0
        }
        for case let fileURL as URL in fileEnumerator {
            // filter thumb
            if url.lastPathComponent == AttachmentContainer.Category.videos.pathComponent, fileURL.lastPathComponent.contains(ExtensionName.jpeg.withDot)  {
                continue
            }
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if let isRegularFile = resourceValues.isRegularFile, isRegularFile {
                    count += 1
                }
            } catch {
                Logger.general.info(category: "DeviceTransferServerDataSender", message: "Failed to get file path: \(error)")
            }
        }
        return count
    }
    
}
