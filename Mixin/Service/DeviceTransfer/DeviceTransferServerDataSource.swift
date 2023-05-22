import Foundation
import MixinServices

final class DeviceTransferServerDataSource {
    
    private let limit = 100
    private let fileChunkSize = 10 * Int(bytesPerMegaByte)
    private let remotePlatform: DeviceTransferPlatform
    private let fileContentBuffer: UnsafeMutablePointer<UInt8>
    
    init(remotePlatform: DeviceTransferPlatform) {
        self.remotePlatform = remotePlatform
        self.fileContentBuffer = .allocate(capacity: fileChunkSize)
    }
    
    deinit {
        fileContentBuffer.deallocate()
    }
    
}

// MARK: - Data Count
extension DeviceTransferServerDataSource {
    
    func totalCount() -> Int {
        assert(!Queue.main.isCurrent)
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
        Logger.general.info(category: "DeviceTransferServerDataSource", message: "Total: \(total), Messages: \(messagesCount), attachments: \(attachmentsCount)")
        return total
    }
    
    private func attachmentsCount() -> Int {
        let folders = AttachmentContainer.Category.allCases.map(\.pathComponent) + ["Transcript"]
        let count = folders.reduce(0) { previousCount, folder in
            let folderURL = AttachmentContainer.url.appendingPathComponent(folder)
            let count = validFileCount(in: folderURL)
            return previousCount + count
        }
        return count
    }
    
    private func validFileCount(in url: URL) -> Int {
        var count = 0
        guard let fileEnumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return 0
        }
        for case let fileURL as URL in fileEnumerator {
            if url.lastPathComponent == AttachmentContainer.Category.videos.pathComponent, fileURL.lastPathComponent.contains(ExtensionName.jpeg.withDot) {
                // Skip video thumbnails
                continue
            }
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if let isRegularFile = resourceValues.isRegularFile, isRegularFile {
                    count += 1
                }
            } catch {
                Logger.general.info(category: "DeviceTransferServerDataSource", message: "Failed to get file path: \(error)")
            }
        }
        return count
    }
    
}

// MARK: - Items
extension DeviceTransferServerDataSource {
    
    private struct Location {
        let type: DeviceTransferRecordType
        let primaryID: String?
        let secondaryID: String?
    }
    
    private struct TransferItem {
        
        struct Attachment {
            let messageID: String
            let url: URL
        }
        
        let rawItem: Codable
        let outputData: Data
        let attachment: Attachment?
        
        init?(rawItem: Codable, outputData: Data?, attachment: Attachment?) {
            guard let outputData else {
                return nil
            }
            self.rawItem = rawItem
            self.outputData = outputData
            self.attachment = attachment
        }
        
    }
    
    func enumerateItems(using block: (_ data: Data, _ stop: inout Bool) -> Void) {
        var nextLocation: Location? = Location(type: .allCases[0], primaryID: nil, secondaryID: nil)
        while let location = nextLocation {
            let (transferItems, nextPrimaryID, nextSecondaryID) = items(on: location)
            if transferItems.isEmpty {
                Logger.general.warn(category: "DeviceTransferServerDataSource", message: "\(location.type) is empty")
            }
            for item in transferItems {
                var stop = false
                block(item.outputData, &stop)
                if stop {
                    return
                }
                if let attachment = item.attachment {
                    readAttachment(attachment, using: block)
                }
            }
            if transferItems.count < limit {
                if let nextType = DeviceTransferRecordType.allCases.element(after: location.type) {
                    nextLocation = Location(type: nextType, primaryID: nil, secondaryID: nil)
                } else {
                    nextLocation = nil
                }
            } else {
                nextLocation = Location(type: location.type, primaryID: nextPrimaryID, secondaryID: nextSecondaryID)
            }
        }
    }
    
    private func items(on location: Location) -> (items: [TransferItem], nextPrimaryID: String?, nextSecondaryID: String?) {
        let transferItems: [TransferItem]
        let nextPrimaryID: String?
        let nextSecondaryID: String?
        
        switch location.type {
        case .conversation:
            let conversations = ConversationDAO.shared.conversations(limit: limit, after: location.primaryID)
            nextPrimaryID = conversations.last?.conversationId
            nextSecondaryID = nil
            transferItems = conversations.compactMap { conversation in
                let deviceTransferConversation = DeviceTransferConversation(conversation: conversation, to: remotePlatform)
                let outputData = DeviceTransferProtocol.output(type: location.type, data: deviceTransferConversation)
                return TransferItem(rawItem: conversation, outputData: outputData, attachment: nil)
            }
        case .participant:
            let participants = ParticipantDAO.shared.participants(limit: limit, after: location.primaryID, with: location.secondaryID)
            nextPrimaryID = participants.last?.conversationId
            nextSecondaryID = participants.last?.userId
            transferItems = participants.compactMap { participant in
                let deviceTransferParticipant = DeviceTransferParticipant(participant: participant)
                let outputData = DeviceTransferProtocol.output(type: location.type, data: deviceTransferParticipant)
                return TransferItem(rawItem: participant, outputData: outputData, attachment: nil)
            }
        case .user:
            let users = UserDAO.shared.users(limit: limit, after: location.primaryID)
            nextPrimaryID = users.last?.userId
            nextSecondaryID = nil
            transferItems = users.compactMap { user in
                let deviceTransferUser = DeviceTransferUser(user: user)
                let outputData = DeviceTransferProtocol.output(type: location.type, data: deviceTransferUser)
                return TransferItem(rawItem: user, outputData: outputData, attachment: nil)
            }
        case .app:
            let apps = AppDAO.shared.apps(limit: limit, after: location.primaryID)
            nextPrimaryID = apps.last?.appId
            nextSecondaryID = nil
            transferItems = apps.compactMap { app in
                let deviceTransferApp = DeviceTransferApp(app: app)
                let outputData = DeviceTransferProtocol.output(type: location.type, data: deviceTransferApp)
                return TransferItem(rawItem: app, outputData: outputData, attachment: nil)
            }
        case .asset:
            let assets = AssetDAO.shared.assets(limit: limit, after: location.primaryID)
            nextPrimaryID = assets.last?.assetId
            nextSecondaryID = nil
            transferItems = assets.compactMap { asset in
                let deviceTransferAsset = DeviceTransferAsset(asset: asset)
                let outputData = DeviceTransferProtocol.output(type: location.type, data: deviceTransferAsset)
                return TransferItem(rawItem: asset, outputData: outputData, attachment: nil)
            }
        case .snapshot:
            let snapshots = SnapshotDAO.shared.snapshots(limit: limit, after: location.primaryID)
            nextPrimaryID = snapshots.last?.snapshotId
            nextSecondaryID = nil
            transferItems = snapshots.compactMap { snapshot in
                let deviceTransferSnapshot = DeviceTransferSnapshot(snapshot: snapshot)
                let outputData = DeviceTransferProtocol.output(type: location.type, data: deviceTransferSnapshot)
                return TransferItem(rawItem: snapshot, outputData: outputData, attachment: nil)
            }
        case .sticker:
            let stickers = StickerDAO.shared.stickers(limit: limit, after: location.primaryID)
            nextPrimaryID = stickers.last?.stickerId
            nextSecondaryID = nil
            transferItems = stickers.compactMap { sticker in
                let deviceTransferSticker = DeviceTransferSticker(sticker: sticker)
                let outputData = DeviceTransferProtocol.output(type: location.type, data: deviceTransferSticker)
                return TransferItem(rawItem: sticker, outputData: outputData, attachment: nil)
            }
        case .pinMessage:
            let pinMessages = PinMessageDAO.shared.pinMessages(limit: limit, after: location.primaryID)
            nextPrimaryID = pinMessages.last?.messageId
            nextSecondaryID = nil
            transferItems = pinMessages.compactMap { pinMessage in
                let deviceTransferPinMessage = DeviceTransferPinMessage(pinMessage: pinMessage)
                let outputData = DeviceTransferProtocol.output(type: location.type, data: deviceTransferPinMessage)
                return TransferItem(rawItem: pinMessage, outputData: outputData, attachment: nil)
            }
        case .transcriptMessage:
            let transcriptMessages = TranscriptMessageDAO.shared.transcriptMessages(limit: limit, after: location.primaryID, with: location.secondaryID)
            nextPrimaryID = transcriptMessages.last?.transcriptId
            nextSecondaryID = transcriptMessages.last?.messageId
            transferItems = transcriptMessages.compactMap { transcriptMessage in
                let deviceTransferTranscriptMessage = DeviceTransferTranscriptMessage(transcriptMessage: transcriptMessage)
                let outputData = DeviceTransferProtocol.output(type: location.type, data: deviceTransferTranscriptMessage)
                if let mediaURL = transcriptMessage.mediaUrl, !mediaURL.isEmpty {
                    let url = AttachmentContainer.url(transcriptId: transcriptMessage.transcriptId, filename: mediaURL)
                    let attachment = TransferItem.Attachment(messageID: transcriptMessage.messageId, url: url)
                    return TransferItem(rawItem: transcriptMessage, outputData: outputData, attachment: attachment)
                } else {
                    return TransferItem(rawItem: transcriptMessage, outputData: outputData, attachment: nil)
                }
            }
        case .message:
            let messages = MessageDAO.shared.messages(limit: limit, after: location.primaryID)
            nextPrimaryID = messages.last?.messageId
            nextSecondaryID = nil
            transferItems = messages.compactMap { message in
                let deviceTransferMessage = DeviceTransferMessage(message: message)
                let outputData = DeviceTransferProtocol.output(type: location.type, data: deviceTransferMessage)
                if let mediaURL = message.mediaUrl, !mediaURL.isEmpty, let category = AttachmentContainer.Category(messageCategory: message.category) {
                    let url = AttachmentContainer.url(for: category, filename: mediaURL)
                    let attachment = TransferItem.Attachment(messageID: message.messageId, url: url)
                    return TransferItem(rawItem: message, outputData: outputData, attachment: attachment)
                } else {
                    return TransferItem(rawItem: message, outputData: outputData, attachment: nil)
                }
            }
        case .messageMention:
            let messageMentions = MessageMentionDAO.shared.messageMentions(limit: limit, after: location.primaryID)
            nextPrimaryID = messageMentions.last?.messageId
            nextSecondaryID = nil
            transferItems = messageMentions.compactMap { messageMention in
                let deviceTransferMessageMention = DeviceTransferMessageMention(messageMention: messageMention)
                let outputData = DeviceTransferProtocol.output(type: location.type, data: deviceTransferMessageMention)
                return TransferItem(rawItem: messageMention, outputData: outputData, attachment: nil)
            }
        case .expiredMessage:
            let expiredMessages = ExpiredMessageDAO.shared.expiredMessages(limit: limit, after: location.primaryID)
            nextPrimaryID = expiredMessages.last?.messageId
            nextSecondaryID = nil
            transferItems = expiredMessages.compactMap { expiredMessage in
                let deviceTransferExpiredMessage = DeviceTransferExpiredMessage(expiredMessage: expiredMessage)
                let outputData = DeviceTransferProtocol.output(type: location.type, data: deviceTransferExpiredMessage)
                return TransferItem(rawItem: expiredMessage, outputData: outputData, attachment: nil)
            }
        }
        
        Logger.general.info(category: "DeviceTransferServerDataSource", message: "Send \(transferItems.count) \(location.type)")
        return (transferItems, nextPrimaryID, nextSecondaryID)
    }
    
    private func readAttachment(_ attachment: TransferItem.Attachment, using block: (Data, inout Bool) -> Void) {
        guard let idData = UUID(uuidString: attachment.messageID)?.data else {
            Logger.general.error(category: "DeviceTransferServerDataSource", message: "Invalid mid: \(attachment.messageID)")
            return
        }
        
        let url = attachment.url
        guard let stream = InputStream(url: url) else {
            Logger.general.info(category: "DeviceTransferServerDataSource", message: "Open stream failed: \(url)")
            return
        }
        
        Logger.general.debug(category: "DeviceTransferServerDataSource", message: "Send File: \(url)")
        
        var stop = false
        
        let length = Int32(idData.count) + Int32(FileManager.default.fileSize(url.path))
        let header = DeviceTransferHeader(type: .file, length: length)
        let headerData = header.encoded()
        block(headerData, &stop)
        if stop {
            return
        }
        
        block(idData, &stop)
        if stop {
            return
        }
        
        var checksum = CRC32()
        checksum.update(data: idData)
        
        stream.open()
        while stream.hasBytesAvailable {
            let bytesRead = stream.read(fileContentBuffer, maxLength: fileChunkSize)
            guard bytesRead > 0 else {
                if let error = stream.streamError {
                    Logger.general.error(category: "DeviceTransferServerDataSender", message: "Read stream failed: \(error), path: \(url.path)")
                }
                break
            }
            let data = Data(bytes: fileContentBuffer, count: bytesRead)
            checksum.update(data: data)
            block(data, &stop)
            if stop {
                break
            }
        }
        stream.close()
        
        let checksumData = checksum.finalize().data(endianness: .big)
        block(checksumData, &stop)
    }
    
}
