import Foundation
import CommonCrypto
import MixinServices

final class DeviceTransferServerDataSource {
    
    private let limit = 100
    private let fileChunkSize = 600000 * kCCBlockSizeAES128 // About 9.1 MiB
    private let key: DeviceTransferKey
    private let filter: DeviceTransferFilter
    private let remotePlatform: DeviceTransferPlatform
    private let fileContentBuffer: UnsafeMutablePointer<UInt8>
    
    init(key: DeviceTransferKey, filter: DeviceTransferFilter, remotePlatform: DeviceTransferPlatform) {
        self.key = key
        self.filter = filter
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
        let messageRowID: Int?
        let pinMessageRowID: Int?
        if let createdAt = filter.earliestCreatedAt {
            messageRowID = MessageDAO.shared.messageRowID(createdAt: createdAt)
            pinMessageRowID = PinMessageDAO.shared.messageRowID(createdAt: createdAt)
        } else {
            messageRowID = nil
            pinMessageRowID = nil
        }
        let conversationIDs: [String]?
        switch filter.conversation {
        case .all:
            conversationIDs = nil
        case .byDatabase(let ids), .byApplication(let ids):
            conversationIDs = Array(ids)
        }
        let messagesCount = MessageDAO.shared.messagesCount(matching: conversationIDs, after: messageRowID)
        let attachmentsCount = filter.isPassthrough
            ? allAttachmentsCount()
            : MessageDAO.shared.mediaMessagesCount(matching: conversationIDs, after: messageRowID)
        let transcriptMessageCount = filter.isPassthrough
            ? TranscriptMessageDAO.shared.transcriptMessagesCount()
            : MessageDAO.shared.transcriptMessageCount(matching: conversationIDs, after: messageRowID)
        let total = ConversationDAO.shared.conversationsCount(matching: conversationIDs)
            + ParticipantDAO.shared.participantsCount(matching: conversationIDs)
            + UserDAO.shared.usersCount()
            + AppDAO.shared.appsCount()
            + AssetDAO.shared.assetsCount()
            + SnapshotDAO.shared.snapshotsCount()
            + StickerDAO.shared.stickersCount()
            + PinMessageDAO.shared.pinMessagesCount(matching: conversationIDs, after: pinMessageRowID)
            + transcriptMessageCount
            + messagesCount
            + MessageMentionDAO.shared.messageMentionsCount(matching: conversationIDs)
            + ExpiredMessageDAO.shared.expiredMessagesCount()
            + attachmentsCount
        Logger.general.info(category: "DeviceTransferServerDataSource", message: "Total: \(total), Messages: \(messagesCount), Attachments: \(attachmentsCount), TranscriptMessages: \(transcriptMessageCount)")
        return total
    }
    
    private func allAttachmentsCount() -> Int {
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
        let rowID: Int?
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
    
    private struct QueryResult {
        
        static let empty = QueryResult(databaseItemCount: 0,
                                       transferItems: [],
                                       dependenciesCount: 0,
                                       lastPrimaryID: nil,
                                       lastSecondaryID: nil,
                                       lastRowID: nil)
        
        let databaseItemCount: Int
        let transferItems: [TransferItem]
        
        // Some items in `transferItems` are dependencies of other items.
        // Currently, there is only one case. When a non-passthrough filter is applied,
        // transcript messages are not sent as a whole before sending messages.
        // Instead, they are sent in batches along with the messages. In this case,
        // `transferItems` includes two types of items: first, the dependent
        // transcript messages, followed by the messages that depend on them.
        // To separately count the quantity of these two types of items, it is necessary
        // to specifically indicate the number of dependent items here.
        let dependenciesCount: Int
        
        let lastPrimaryID: String?
        let lastSecondaryID: String?
        let lastRowID: Int?
        
    }
    
    // Only throw fatal errors, like encryption failure for now
    func enumerateItems(using block: (_ data: Data, _ stop: inout Bool) -> Void) throws {
        let applicationFilteringIDs = filter.conversation.applicationFilteringIDs
        let databaseFilteringIDs = filter.conversation.databaseFilteringIDs
        let isPassthroughFilter = filter.isPassthrough
        
        var nextLocation: Location? = Location(type: .allCases[0], primaryID: nil, secondaryID: nil, rowID: nil)
        var recordCount = 0
        var dependenciesCount = 0 // See QueryResult.dependenciesCount
        var fileCount = 0
        
        while let location = nextLocation {
            let result = queryItems(on: location,
                                    applicationFilteringIDs: applicationFilteringIDs,
                                    databaseFilteringIDs: databaseFilteringIDs)
            if result.transferItems.isEmpty {
                Logger.general.info(category: "DeviceTransferServerDataSource",
                                    message: "\(location.type) is empty, passthrough: \(isPassthroughFilter)")
            }
            recordCount += (result.transferItems.count - result.dependenciesCount)
            dependenciesCount += result.dependenciesCount
            for item in result.transferItems {
                var stop = false
                block(item.outputData, &stop)
                if stop {
                    return
                }
                if let attachment = item.attachment {
                    if try readAttachment(attachment, using: block) {
                        fileCount += 1
                    }
                }
            }
            if result.databaseItemCount < limit {
                if let nextType = DeviceTransferRecordType.allCases.element(after: location.type) {
                    nextLocation = Location(type: nextType, primaryID: nil, secondaryID: nil, rowID: nil)
                } else {
                    nextLocation = nil
                }
                Logger.general.info(category: "DeviceTransferServerDataSource", message: "Send \(recordCount) \(location.type)")
                if dependenciesCount != 0 {
                    Logger.general.info(category: "DeviceTransferServerDataSource", message: "Send \(dependenciesCount) dependencies")
                }
                recordCount = 0
                dependenciesCount = 0
            } else {
                nextLocation = Location(type: location.type,
                                        primaryID: result.lastPrimaryID,
                                        secondaryID: result.lastSecondaryID,
                                        rowID: result.lastRowID)
            }
        }
        Logger.general.info(category: "DeviceTransferServerDataSource", message: "Send file \(fileCount)")
    }
    
    private func queryItems(
        on location: Location,
        applicationFilteringIDs: Set<String>?,
        databaseFilteringIDs: Set<String>?
    ) -> QueryResult {
        switch location.type {
        case .conversation:
            let conversations = ConversationDAO.shared.conversations(limit: limit,
                                                                     after: location.primaryID,
                                                                     matching: databaseFilteringIDs)
            let transferItems: [TransferItem] = conversations.compactMap { conversation in
                if let applicationFilteringIDs, !applicationFilteringIDs.contains(conversation.conversationId) {
                    return nil
                }
                let deviceTransferConversation = DeviceTransferConversation(conversation: conversation, to: remotePlatform)
                do {
                    let outputData = try DeviceTransferProtocol.output(type: location.type, data: deviceTransferConversation, key: key)
                    return TransferItem(rawItem: conversation, outputData: outputData, attachment: nil)
                } catch {
                    Logger.general.error(category: "DeviceTransferServerDataSource", message: "Failed to output: \(error)")
                    return nil
                }
            }
            return QueryResult(databaseItemCount: conversations.count,
                               transferItems: transferItems,
                               dependenciesCount: 0,
                               lastPrimaryID: conversations.last?.conversationId,
                               lastSecondaryID: nil,
                               lastRowID: nil)
        case .participant:
            let participants = ParticipantDAO.shared.participants(limit: limit,
                                                                  after: location.primaryID,
                                                                  with: location.secondaryID,
                                                                  matching: databaseFilteringIDs)
            let transferItems: [TransferItem] = participants.compactMap { participant in
                if let applicationFilteringIDs, !applicationFilteringIDs.contains(participant.conversationId) {
                    return nil
                }
                let deviceTransferParticipant = DeviceTransferParticipant(participant: participant)
                do {
                    let outputData = try DeviceTransferProtocol.output(type: location.type, data: deviceTransferParticipant, key: key)
                    return TransferItem(rawItem: participant, outputData: outputData, attachment: nil)
                } catch {
                    Logger.general.error(category: "DeviceTransferServerDataSource", message: "Failed to output: \(error)")
                    return nil
                }
            }
            return QueryResult(databaseItemCount: participants.count,
                               transferItems: transferItems,
                               dependenciesCount: 0,
                               lastPrimaryID: participants.last?.conversationId,
                               lastSecondaryID: participants.last?.userId,
                               lastRowID: nil)
        case .user:
            let users = UserDAO.shared.users(limit: limit, after: location.primaryID)
            let transferItems: [TransferItem] = users.compactMap { user in
                let deviceTransferUser = DeviceTransferUser(user: user)
                do {
                    let outputData = try DeviceTransferProtocol.output(type: location.type, data: deviceTransferUser, key: key)
                    return TransferItem(rawItem: user, outputData: outputData, attachment: nil)
                } catch {
                    Logger.general.error(category: "DeviceTransferServerDataSource", message: "Failed to output: \(error)")
                    return nil
                }
            }
            return QueryResult(databaseItemCount: users.count,
                               transferItems: transferItems,
                               dependenciesCount: 0,
                               lastPrimaryID: users.last?.userId,
                               lastSecondaryID: nil,
                               lastRowID: nil)
        case .app:
            let apps = AppDAO.shared.apps(limit: limit, after: location.primaryID)
            let transferItems: [TransferItem] = apps.compactMap { app in
                let deviceTransferApp = DeviceTransferApp(app: app)
                do {
                    let outputData = try DeviceTransferProtocol.output(type: location.type, data: deviceTransferApp, key: key)
                    return TransferItem(rawItem: app, outputData: outputData, attachment: nil)
                } catch {
                    Logger.general.error(category: "DeviceTransferServerDataSource", message: "Failed to output: \(error)")
                    return nil
                }
            }
            return QueryResult(databaseItemCount: apps.count,
                               transferItems: transferItems,
                               dependenciesCount: 0,
                               lastPrimaryID: apps.last?.appId,
                               lastSecondaryID: nil,
                               lastRowID: nil)
        case .asset:
            let assets = AssetDAO.shared.assets(limit: limit, after: location.primaryID)
            let transferItems: [TransferItem] = assets.compactMap { asset in
                let deviceTransferAsset = DeviceTransferAsset(asset: asset)
                do {
                    let outputData = try DeviceTransferProtocol.output(type: location.type, data: deviceTransferAsset, key: key)
                    return TransferItem(rawItem: asset, outputData: outputData, attachment: nil)
                } catch {
                    Logger.general.error(category: "DeviceTransferServerDataSource", message: "Failed to output: \(error)")
                    return nil
                }
            }
            return QueryResult(databaseItemCount: assets.count,
                               transferItems: transferItems,
                               dependenciesCount: 0,
                               lastPrimaryID: assets.last?.assetId,
                               lastSecondaryID: nil,
                               lastRowID: nil)
        case .snapshot:
            let snapshots = SnapshotDAO.shared.snapshots(limit: limit, after: location.primaryID)
            let transferItems: [TransferItem] = snapshots.compactMap { snapshot in
                let deviceTransferSnapshot = DeviceTransferSnapshot(snapshot: snapshot)
                do {
                    let outputData = try DeviceTransferProtocol.output(type: location.type, data: deviceTransferSnapshot, key: key)
                    return TransferItem(rawItem: snapshot, outputData: outputData, attachment: nil)
                } catch {
                    Logger.general.error(category: "DeviceTransferServerDataSource", message: "Failed to output: \(error)")
                    return nil
                }
            }
            return QueryResult(databaseItemCount: snapshots.count,
                               transferItems: transferItems,
                               dependenciesCount: 0,
                               lastPrimaryID: snapshots.last?.snapshotId,
                               lastSecondaryID: nil,
                               lastRowID: nil)
        case .sticker:
            let stickers = StickerDAO.shared.stickers(limit: limit, after: location.primaryID)
            let transferItems: [TransferItem] = stickers.compactMap { sticker in
                let deviceTransferSticker = DeviceTransferSticker(sticker: sticker)
                do {
                    let outputData = try DeviceTransferProtocol.output(type: location.type, data: deviceTransferSticker, key: key)
                    return TransferItem(rawItem: sticker, outputData: outputData, attachment: nil)
                } catch {
                    Logger.general.error(category: "DeviceTransferServerDataSource", message: "Failed to output: \(error)")
                    return nil
                }
            }
            return QueryResult(databaseItemCount: stickers.count,
                               transferItems: transferItems,
                               dependenciesCount: 0,
                               lastPrimaryID: stickers.last?.stickerId,
                               lastSecondaryID: nil,
                               lastRowID: nil)
        case .pinMessage:
            let rowID: Int
            if let id = location.rowID {
                rowID = id
            } else if let createdAt = filter.earliestCreatedAt {
                if let firstRowID = PinMessageDAO.shared.messageRowID(createdAt: createdAt) {
                    rowID = firstRowID - 1
                } else {
                    return .empty
                }
            } else {
                rowID = -1
            }
            let pinMessages = PinMessageDAO.shared.pinMessages(limit: limit,
                                                               after: rowID,
                                                               matching: databaseFilteringIDs)
            let lastRowID: Int?
            if let messageID = pinMessages.last?.messageId {
                lastRowID = PinMessageDAO.shared.messageRowID(messageID: messageID)
            } else {
                lastRowID = nil
            }
            let transferItems: [TransferItem] = pinMessages.compactMap { pinMessage in
                if let applicationFilteringIDs, !applicationFilteringIDs.contains(pinMessage.conversationId) {
                    return nil
                }
                if let earliestCreatedAt = filter.earliestCreatedAt, pinMessage.createdAt < earliestCreatedAt {
                    return nil
                }
                let deviceTransferPinMessage = DeviceTransferPinMessage(pinMessage: pinMessage)
                do {
                    let outputData = try DeviceTransferProtocol.output(type: location.type, data: deviceTransferPinMessage, key: key)
                    return TransferItem(rawItem: pinMessage, outputData: outputData, attachment: nil)
                } catch {
                    Logger.general.error(category: "DeviceTransferServerDataSource", message: "Failed to output: \(error)")
                    return nil
                }
            }
            return QueryResult(databaseItemCount: pinMessages.count,
                               transferItems: transferItems,
                               dependenciesCount: 0,
                               lastPrimaryID: nil,
                               lastSecondaryID: nil,
                               lastRowID: lastRowID)
        case .transcriptMessage:
            if filter.isPassthrough {
                let transcriptMessages = TranscriptMessageDAO.shared.transcriptMessages(limit: limit, after: location.primaryID, with: location.secondaryID)
                let transferItems = transcriptTransferItems(for: transcriptMessages)
                return QueryResult(databaseItemCount: transcriptMessages.count,
                                   transferItems: transferItems,
                                   dependenciesCount: 0,
                                   lastPrimaryID: transcriptMessages.last?.transcriptId,
                                   lastSecondaryID: transcriptMessages.last?.messageId,
                                   lastRowID: nil)
            } else {
                return .empty
            }
        case .message:
            let rowID: Int
            if let id = location.rowID {
                rowID = id
            } else if let createdAt = filter.earliestCreatedAt {
                if let firstRowID = MessageDAO.shared.messageRowID(createdAt: createdAt) {
                    rowID = firstRowID - 1
                } else {
                    return .empty
                }
            } else {
                rowID = -1
            }
            let messages = MessageDAO.shared.messages(limit: limit,
                                                      after: rowID,
                                                      matching: databaseFilteringIDs)
            let lastRowID: Int?
            if let messageID = messages.last?.messageId {
                lastRowID = MessageDAO.shared.messageRowID(messageID: messageID)
            } else {
                lastRowID = nil
            }
            var messageItems = [TransferItem]()
            var transcriptMessageItems = [TransferItem]()
            for message in messages {
                if let applicationFilteringIDs, !applicationFilteringIDs.contains(message.conversationId) {
                    continue
                }
                if let earliestCreatedAt = filter.earliestCreatedAt, message.createdAt < earliestCreatedAt {
                    continue
                }
                let deviceTransferMessage = DeviceTransferMessage(message: message, to: remotePlatform)
                do {
                    let outputData = try DeviceTransferProtocol.output(type: location.type, data: deviceTransferMessage, key: key)
                    let attachment: TransferItem.Attachment?
                    if let mediaURL = message.mediaUrl, !mediaURL.isEmpty, message.mediaStatus == MediaStatus.DONE.rawValue, let category = AttachmentContainer.Category(messageCategory: message.category) {
                        let url = AttachmentContainer.url(for: category, filename: mediaURL)
                        attachment = TransferItem.Attachment(messageID: message.messageId, url: url)
                    } else {
                        attachment = nil
                    }
                    if let item = TransferItem(rawItem: message, outputData: outputData, attachment: attachment) {
                        messageItems.append(item)
                    }
                } catch {
                    Logger.general.error(category: "DeviceTransferServerDataSource", message: "Failed to output message: \(error)")
                }
                // TranscriptMessage
                if !filter.isPassthrough && message.category.hasSuffix("_TRANSCRIPT") {
                    let transcriptMessages = TranscriptMessageDAO.shared.transcriptMessages(transcriptId: message.messageId)
                    transcriptMessageItems = transcriptTransferItems(for: transcriptMessages)
                }
            }
            return QueryResult(databaseItemCount: messages.count,
                               transferItems: transcriptMessageItems + messageItems,
                               dependenciesCount: transcriptMessageItems.count,
                               lastPrimaryID: nil,
                               lastSecondaryID: nil,
                               lastRowID: lastRowID)
        case .messageMention:
            let messageMentions = MessageMentionDAO.shared.messageMentions(limit: limit,
                                                                           after: location.primaryID,
                                                                           matching: databaseFilteringIDs)
            let transferItems: [TransferItem] = messageMentions.compactMap { messageMention in
                if let applicationFilteringIDs, !applicationFilteringIDs.contains(messageMention.conversationId) {
                    return nil
                }
                let deviceTransferMessageMention = DeviceTransferMessageMention(messageMention: messageMention)
                do {
                    let outputData = try DeviceTransferProtocol.output(type: location.type, data: deviceTransferMessageMention, key: key)
                    return TransferItem(rawItem: messageMention, outputData: outputData, attachment: nil)
                } catch {
                    Logger.general.error(category: "DeviceTransferServerDataSource", message: "Failed to output: \(error)")
                    return nil
                }
            }
            return QueryResult(databaseItemCount: messageMentions.count,
                               transferItems: transferItems,
                               dependenciesCount: 0,
                               lastPrimaryID: messageMentions.last?.messageId,
                               lastSecondaryID: nil,
                               lastRowID: nil)
        case .expiredMessage:
            let expiredMessages = ExpiredMessageDAO.shared.expiredMessages(limit: limit, after: location.primaryID)
            let transferItems: [TransferItem] = expiredMessages.compactMap { expiredMessage in
                let deviceTransferExpiredMessage = DeviceTransferExpiredMessage(expiredMessage: expiredMessage)
                do {
                    let outputData = try DeviceTransferProtocol.output(type: location.type, data: deviceTransferExpiredMessage, key: key)
                    return TransferItem(rawItem: expiredMessage, outputData: outputData, attachment: nil)
                } catch {
                    Logger.general.error(category: "DeviceTransferServerDataSource", message: "Failed to output: \(error)")
                    return nil
                }
            }
            return QueryResult(databaseItemCount: expiredMessages.count,
                               transferItems: transferItems,
                               dependenciesCount: 0,
                               lastPrimaryID: expiredMessages.last?.messageId,
                               lastSecondaryID: nil,
                               lastRowID: nil)
        }
    }
    
    // Only throw fatal errors, like encryption failure for now
    private func readAttachment(_ attachment: TransferItem.Attachment, using block: (Data, inout Bool) -> Void) throws -> Bool {
        let url = attachment.url
        let fileSize = Int(FileManager.default.fileSize(url.path))
        guard fileSize > 0 else {
            return false
        }
        
        guard let idData = UUID(uuidString: attachment.messageID)?.data else {
            Logger.general.error(category: "DeviceTransferServerDataSource", message: "Invalid mid: \(attachment.messageID)")
            return false
        }
        guard let stream = InputStream(url: url) else {
            Logger.general.info(category: "DeviceTransferServerDataSource", message: "Open stream failed: \(url)")
            return false
        }
        guard let iv = Data(withNumberOfSecuredRandomBytes: DeviceTransferProtocol.ivDataCount) else {
            Logger.general.error(category: "DeviceTransferServerDataSource", message: "Unable to generate iv for attachment")
            return false
        }
#if DEBUG
        Logger.general.debug(category: "DeviceTransferServerDataSource", message: "Send File: \(url)")
#endif
        
        let encryptor = try AESCryptor(operation: .encrypt, iv: iv, key: key.aes)
        let encryptedFileSize = encryptor.outputDataCount(inputDataCount: fileSize, isFinal: true)
        encryptor.reserveOutputBufferCapacity(min(encryptedFileSize, fileChunkSize))
        
        var stop = false
        var hmac = HMACSHA256(key: key.hmac)
        
        let length = idData.count + iv.count + encryptedFileSize
        let header = DeviceTransferHeader(type: .file, length: Int32(length))
        let headerData = header.encoded()
        block(headerData, &stop)
        if stop {
            return false
        }
        
        block(idData, &stop)
        if stop {
            return false
        }
        hmac.update(data: idData)
        
        block(iv, &stop)
        if stop {
            return false
        }
        hmac.update(data: iv)
        
        stream.open()
        while stream.hasBytesAvailable {
            let bytesRead = stream.read(fileContentBuffer, maxLength: fileChunkSize)
            guard bytesRead > 0 else {
                if let error = stream.streamError {
                    Logger.general.error(category: "DeviceTransferServerDataSender", message: "Read stream failed: \(error), path: \(url.path)")
                }
                break
            }
            let chunk = Data(bytesNoCopy: fileContentBuffer, count: bytesRead, deallocator: .none)
            let encryptedChunk = try encryptor.update(chunk)
            hmac.update(data: encryptedChunk)
            block(encryptedChunk, &stop)
            if stop {
                break
            }
        }
        stream.close()
        
        let finalChunk = try encryptor.finalize()
        hmac.update(data: finalChunk)
        block(finalChunk, &stop)
        
        let hmacData = hmac.finalize()
        block(hmacData, &stop)
        return true
    }
    
    private func transcriptTransferItems(for transcriptMessages: [TranscriptMessage]) -> [TransferItem] {
        transcriptMessages.compactMap { transcriptMessage in
            let deviceTransferTranscriptMessage = DeviceTransferTranscriptMessage(transcriptMessage: transcriptMessage, to: remotePlatform)
            do {
                let outputData = try DeviceTransferProtocol.output(type: .transcriptMessage, data: deviceTransferTranscriptMessage, key: key)
                if let mediaURL = transcriptMessage.mediaUrl, !mediaURL.isEmpty, transcriptMessage.mediaStatus == MediaStatus.DONE.rawValue {
                    let url = AttachmentContainer.url(transcriptId: transcriptMessage.transcriptId, filename: mediaURL)
                    let attachment = TransferItem.Attachment(messageID: transcriptMessage.messageId, url: url)
                    return TransferItem(rawItem: transcriptMessage, outputData: outputData, attachment: attachment)
                } else {
                    return TransferItem(rawItem: transcriptMessage, outputData: outputData, attachment: nil)
                }
            } catch {
                Logger.general.error(category: "DeviceTransferServerDataSource", message: "Failed to output: \(error)")
                return nil
            }
        }
    }
    
}
