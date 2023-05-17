import Foundation
import MixinServices

protocol DeviceTransferClientDataWriterDelegate: AnyObject {
    
    func deviceTransferClientDataWriter(_ writer: DeviceTransferClientDataWriter, update progress: Float)
    
}

class DeviceTransferClientDataWriter {
    
    private struct TypeWrapper: Decodable {
        let type: DeviceTransferMessageType
    }
    
    weak var client: DeviceTransferClient?
    weak var delegate: DeviceTransferClientDataWriterDelegate?
    
    @Synchronized(value: false)
    var canWriteData: Bool {
        didSet {
            if !canWriteData {
                isParsingMessageData = false
                fileIndex = 0
                parsedCount = 0
                totalCount = 0
            }
        }
    }
    
    private let receiveDataQueue = DispatchQueue(label: "one.mixin.messenger.DeviceTransferClientDataWriter.receive")
    private let parseDataQueue = DispatchQueue(label: "one.mixin.messenger.DeviceTransferClientDataWriter.parse")
    private let decoder = JSONDecoder.default
    private let fileManager = FileManager.default
    private let maxFileSize: UInt64 = 10 * 1024 * 1024
    private let payloadLength: UInt64 = 4
    
    private var fileHandle: FileHandle?
    private var fileIndex = 0
    private var totalCount: Double = 0
    private var parsedCount: Double = 0
    private var isParsingMessageData = false
    
    init(client: DeviceTransferClient) {
        self.client = client
        receiveDataQueue.async { [weak self] in
            self?.openNextFile()
        }
    }
    
    func take(_ data: Data) {
        receiveDataQueue.async { [weak self] in
            self?.writeData(data)
        }
    }
    
    // Only one file which is less than maxFileSize
    func parseDataIfNeeded() {
        guard !isParsingMessageData else {
            return
        }
        Logger.general.info(category: "DeviceTransferClientDataWriter", message: "ParseDataIfNeeded")
        parseDataQueue.async { [weak self] in
            self?.readAndParseMessageData(fileIndex: 0)
        }
    }
    
    func cleanFiles() {
        do {
            try fileManager.removeItem(at: AttachmentContainer.deviceTransferURL())
        } catch {
            Logger.general.error(category: "DeviceTransferClientDataWriter", message: "Clean files failed: \(error)")
        }
    }
    
}

extension DeviceTransferClientDataWriter {
    
    private func openNextFile() {
        fileHandle?.closeFile()
        let filePath = AttachmentContainer.deviceTransferDataURL(isFile: false, fileName: "\(fileIndex)").path
        if fileManager.fileExists(atPath: filePath) {
            try? fileManager.removeItem(atPath: filePath)
        }
        fileManager.createFile(atPath: filePath, contents: nil, attributes: nil)
        Logger.general.info(category: "DeviceTransferClientDataWriter", message: "Open Data File: \(filePath)")
        fileHandle = FileHandle(forUpdatingAtPath: filePath)
        fileIndex += 1
    }
    
    private func writeData(_ data: Data) {
        if let fileSize = fileHandle?.seekToEndOfFile(), fileSize + UInt64(data.count) > maxFileSize {
            openNextFile()
            if !isParsingMessageData {
                isParsingMessageData = true
                readAndParseMessageData(fileIndex: 0)
            }
        }
        let lenghtData = UInt32(data.count).data(endianness: .big)
        fileHandle?.write(lenghtData)
        fileHandle?.write(data)
        totalCount += 1
    }
    
    private func readAndParseMessageData(fileIndex: Int) {
        let filePath = AttachmentContainer.deviceTransferDataURL(isFile: false, fileName: "\(fileIndex)")
        parseDataQueue.async { [weak self] in
            guard let self = self else {
                return
            }
            do {
                let fileHandle = try FileHandle(forReadingFrom: filePath)
                let fileSize = fileHandle.seekToEndOfFile()
                Logger.general.info(category: "DeviceTransferClientDataWriter", message: "Read and parse message: \(filePath.path)")
                var index: UInt64 = 0
                while index < fileSize, self.canWriteData {
                    autoreleasepool {
                        fileHandle.seek(toFileOffset: index)
                        let lengthData = fileHandle.readData(ofLength: Int(self.payloadLength))
                        let length = Int(Int32(data: lengthData, endianess: .big))
                        index += self.payloadLength
                        fileHandle.seek(toFileOffset: index)
                        let data = fileHandle.readData(ofLength: Int(length))
                        index += UInt64(length)
                        self.parseMessage(data)
                        self.parsedCount += 1
                        let progress: Float
                        if self.parsedCount >= self.totalCount {
                            self.processFiles()
                            progress = 1
                        } else {
                            progress = Float(self.parsedCount) / Float(self.totalCount + 1)
                        }
                        self.delegate?.deviceTransferClientDataWriter(self, update: progress)
                    }
                }
                fileHandle.closeFile()
                let nextFileIndex = fileIndex + 1
                let nextFilePath = AttachmentContainer.deviceTransferDataURL(isFile: false, fileName: "\(nextFileIndex)").path
                if self.canWriteData, self.fileManager.fileExists(atPath: nextFilePath) {
                    self.readAndParseMessageData(fileIndex: nextFileIndex)
                }
            } catch {
                Logger.general.error(category: "DeviceTransferClientDataWriter", message: "Read and parse data failed: \(error)")
            }
        }
    }
    
    private func parseMessage(_ messageData: Data) {
        do {
            let wrapper = try decoder.decode(TypeWrapper.self, from: messageData)
            switch wrapper.type {
            case .conversation:
                let conversation = try decoder.decode(DeviceTransferData<DeviceTransferConversation>.self, from: messageData).data
                ConversationDAO.shared.save(conversation: conversation.toConversation(from: client?.connectionCommand?.platform))
            case .participant:
                let participant = try decoder.decode(DeviceTransferData<DeviceTransferParticipant>.self, from: messageData).data
                ParticipantDAO.shared.save(participant: participant.toParticipant())
            case .user:
                let user = try decoder.decode(DeviceTransferData<DeviceTransferUser>.self, from: messageData).data
                UserDAO.shared.save(user: user.toUser())
            case .app:
                let app = try decoder.decode(DeviceTransferData<DeviceTransferApp>.self, from: messageData).data
                AppDAO.shared.save(app: app.toApp())
            case .asset:
                let asset = try decoder.decode(DeviceTransferData<DeviceTransferAsset>.self, from: messageData).data
                AssetDAO.shared.save(asset: asset.toAsset())
            case .snapshot:
                let snapshot = try decoder.decode(DeviceTransferData<DeviceTransferSnapshot>.self, from: messageData).data
                SnapshotDAO.shared.save(snapshot: snapshot.toSnapshot())
            case .sticker:
                let sticker = try decoder.decode(DeviceTransferData<DeviceTransferSticker>.self, from: messageData).data
                StickerDAO.shared.save(sticker: sticker.toSticker())
            case .pinMessage:
                let pinMessage = try decoder.decode(DeviceTransferData<DeviceTransferPinMessage>.self, from: messageData).data
                PinMessageDAO.shared.save(pinMessage: pinMessage.toPinMessage())
            case .transcriptMessage:
                let transcriptMessage = try decoder.decode(DeviceTransferData<DeviceTransferTranscriptMessage>.self, from: messageData).data
                TranscriptMessageDAO.shared.save(transcriptMessage: transcriptMessage.toTranscriptMessage())
            case .message:
                let message = try decoder.decode(DeviceTransferData<DeviceTransferMessage>.self, from: messageData).data
                if MessageCategory.isLegal(category: message.category) {
                    MessageDAO.shared.save(message: message.toMessage())
                }
            case .messageMention:
                if let messageMention = try decoder.decode(DeviceTransferData<DeviceTransferMessageMention>.self, from: messageData).data.toMessageMention() {
                    MessageMentionDAO.shared.save(messageMention: messageMention)
                }
            case .expiredMessage:
                let expiredMessage = try decoder.decode(DeviceTransferData<DeviceTransferExpiredMessage>.self, from: messageData).data
                ExpiredMessageDAO.shared.save(expiredMessage: expiredMessage.toExpiredMessage())
            case .unknown:
                Logger.general.error(category: "DeviceTransferClientDataWriter", message: "unknown message: \(String(data: messageData, encoding: .utf8) ?? "")")
            }
        } catch {
            let content = String(data: messageData, encoding: .utf8) ?? "Data(\(messageData.count))"
            Logger.general.error(category: "DeviceTransferClientDataWriter", message: "Error: \(error) Content: \(content)")
        }
    }
    
    private func processFiles() {
        guard
            let fileEnumerator = fileManager.enumerator(at: AttachmentContainer.deviceTransferDataURL(isFile: true, fileName: nil),
                                                        includingPropertiesForKeys: [.isRegularFileKey],
                                                        options: [.skipsHiddenFiles, .skipsPackageDescendants])
        else {
            Logger.general.error(category: "DeviceTransferClientDataWriter", message: "Can't create file enumerator")
            return
        }
        Logger.general.info(category: "DeviceTransferClientDataWriter", message: "Process files")
        for case let fileURL as URL in fileEnumerator {
            let components = fileURL.lastPathComponent.components(separatedBy: ".")
            guard components.count == 2, let fileMessageId = components.first else {
                Logger.general.info(category: "DeviceTransferClientDataWriter", message: "Invalid file url: \(fileURL.path)")
                continue
            }
            let messageFileURL: URL?
            let transcriptMessageFileURL: URL?
            if let message = MessageDAO.shared.getMessage(messageId: fileMessageId), let mediaURL = message.mediaUrl {
                let category = AttachmentContainer.Category(messageCategory: message.category) ?? .files
                messageFileURL = AttachmentContainer.url(for: category, filename: mediaURL)
                if let transcriptMessage = TranscriptMessageDAO.shared.transcriptMessage(messageId: fileMessageId), let mediaURL = transcriptMessage.mediaUrl {
                    transcriptMessageFileURL = AttachmentContainer.url(transcriptId: transcriptMessage.transcriptId, filename: mediaURL)
                } else {
                    transcriptMessageFileURL = nil
                }
            } else if let transcriptMessage = TranscriptMessageDAO.shared.transcriptMessage(messageId: fileMessageId), let mediaURL = transcriptMessage.mediaUrl {
                transcriptMessageFileURL = AttachmentContainer.url(transcriptId: fileMessageId, filename: mediaURL)
                messageFileURL = nil
            } else {
                Logger.general.debug(category: "DeviceTransferClientDataWriter", message: "File message not exists: \(fileURL.path)")
                continue
            }
            if let messageFileURL, !fileManager.fileExists(atPath: messageFileURL.path) {
                do {
                    try fileManager.copyItem(at: fileURL, to: messageFileURL)
                } catch {
                    Logger.general.error(category: "DeviceTransferClientDataWriter", message: "Copy message file failed from \(fileURL) to \(messageFileURL)")
                }
            }
            if let transcriptMessageFileURL, !fileManager.fileExists(atPath: transcriptMessageFileURL.path) {
                do {
                    try fileManager.copyItem(at: fileURL, to: transcriptMessageFileURL)
                } catch {
                    Logger.general.error(category: "DeviceTransferClientDataWriter", message: "Copy transcript message file failed from \(fileURL) to \(transcriptMessageFileURL)")
                }
            }
        }
        do {
            try fileManager.removeItem(at: AttachmentContainer.deviceTransferURL())
        } catch {
            Logger.general.error(category: "DeviceTransferClientDataWriter", message: "Remove DeviceTransfer folder failed: \(error)")
        }
    }
    
}
