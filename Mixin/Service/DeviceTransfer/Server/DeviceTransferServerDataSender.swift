import Foundation
import MixinServices

class DeviceTransferServerDataSender {
    
    weak var server: DeviceTransferServer?
    
    private let limit = 100
    private let fileBufferSize = 1024 * 1024 * 10
    private let maxConcurrentSends = 2
    
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
        let total = ConversationDAO.shared.conversationsCount()
            + ParticipantDAO.shared.participantsCount()
            + UserDAO.shared.usersCount()
            + AssetDAO.shared.assetsCount()
            + SnapshotDAO.shared.snapshotsCount()
            + StickerDAO.shared.stickersCount()
            + PinMessageDAO.shared.pinMessagesCount()
            + TranscriptMessageDAO.shared.transcriptMessagesCount()
            + MessageDAO.shared.messagesCount()
            + ExpiredMessageDAO.shared.expiredMessagesCount()
            + attachmentsCount()
        let command = DeviceTransferCommand(action: .start, total: total)
        if let server, let commandData = server.composer.commandData(command: command) {
            Logger.general.debug(category: "DeviceTransferServer", message: "Send Start Command")
            server.send(data: commandData)
            server.displayState = .transporting(processedCount: 0, totalCount: total)
        }
    }
    
    private func sendFinishCommand() {
        let command = DeviceTransferCommand(action: .finish)
        if let server, let data = server.composer.commandData(command: command) {
            Logger.general.debug(category: "DeviceTransferServer", message: "Send Finish Command")
            server.send(data: data)
        }
    }
    
    private func sendTransferItems(type: DeviceTransferMessageType) {
        guard type != .command, type != .unknown else {
            return
        }
        var offset = 0
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
                transferItems = MessageDAO.shared.messages(limit: limit, offset: offset)
                    .map { DeviceTransferMessage(message: $0) }
            case .expiredMessage:
                transferItems = ExpiredMessageDAO.shared.expiredMessages(limit: limit, offset: offset)
                    .map { DeviceTransferExpiredMessage(expiredMessage: $0) }
            case .command, .unknown:
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
        for path in allFilePaths {
            guard let server, server.canSendData else {
                break
            }
            let components = path.lastPathComponent.components(separatedBy: ".")
            guard components.count == 2, let idData = UUID(uuidString: components[0])?.data else {
                continue
            }
            if type == "Videos", components[1] != "mp4" { // filter thumb
                continue
            }
            guard let stream = InputStream(url: path) else {
                Logger.general.info(category: "DeviceTransferServerDataSender", message: "Open stream failed")
                continue
            }
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
                server.send(data: data)
            }
            stream.close()
            // send checksum data
            let checksumData = checksum.finalize().data(endianness: .big)
            server.send(data: checksumData)
        }
        Logger.general.debug(category: "DeviceTransferServerDataSender", message: "Send \(type)")
    }
    
    private func getAllFilePaths(inDirectory url: URL) -> [URL] {
        var filePaths: [URL] = []
        guard let fileEnumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return filePaths
        }
        for case let fileURL as URL in fileEnumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if let isRegularFile = resourceValues.isRegularFile, isRegularFile {
                    filePaths.append(fileURL)
                }
            } catch {
                Logger.general.error(category: "DeviceTransferServerDataSender", message: "Failed to get file path: \(error)")
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
