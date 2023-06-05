import Foundation
import MixinServices

protocol DeviceTransferDataWriterDelegate: AnyObject {
    
    func deviceTransferDataWriter(_ writer: DeviceTransferDataWriter, update progress: Float)
    
}

final class DeviceTransferDataWriter {
    
    weak var delegate: DeviceTransferDataWriterDelegate?
    
    var canProcessData: Bool = true {
        didSet {
            fileIndex = 0
            parsedRecordCount = 0
            totalRecordCount = 0
            fileHandle = nil
        }
    }
    
    private let remotePlatform: DeviceTransferPlatform
    private let queue = Queue(label: "one.mixin.messenger.DeviceTransferClient.parse")
    
    private var fileHandle: FileHandle?
    private var fileIndex = 0
    private var totalRecordCount = 0
    private var parsedRecordCount = 0
    private var pendingParsedRecordPath = [URL]()
    
    init(remotePlatform: DeviceTransferPlatform) {
        self.remotePlatform = remotePlatform
    }
    
    func write(data: Data) -> Bool {
        if let fileHandle {
            let fileSize = fileHandle.seekToEndOfFile()
            let maxSizeExceeded = fileSize + UInt64(data.count) > DeviceTransferData.maxSizePerFile
            if maxSizeExceeded {
                fileHandle.closeFile()
                let filePath = DeviceTransferData.record.url(index: fileIndex)
                Logger.general.info(category: "DeviceTransferDataWriter", message: "Close file: \(filePath)")
                queue.async {
                    self.pendingParsedRecordPath.append(filePath)
                    self.readAndParseRecordData()
                }
                fileIndex += 1
                openNextFile()
            }
        } else {
            openNextFile()
        }
        guard let fileHandle else {
            Logger.general.warn(category: "DeviceTransferDataWriter", message: "FileHandle is nil")
            return false
        }
        let lenghtData = UInt32(data.count).data(endianness: .big)
        fileHandle.write(lenghtData)
        fileHandle.write(data)
        DispatchQueue.main.async {
            self.totalRecordCount += 1
        }
        return true
    }
    
    func transferFinished() {
        fileHandle?.closeFile()
        let filePath = DeviceTransferData.record.url(index: fileIndex)
        Logger.general.info(category: "DeviceTransferDataWriter", message: "Close file: \(filePath)")
        queue.async {
            self.pendingParsedRecordPath.append(filePath)
            self.readAndParseRecordData()
        }
    }
    
}

extension DeviceTransferDataWriter {
    
    private func openNextFile() {
        let filePath = DeviceTransferData.record.url(index: fileIndex).path
        if FileManager.default.fileExists(atPath: filePath) {
            try? FileManager.default.removeItem(atPath: filePath)
        }
        FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil)
        fileHandle = FileHandle(forUpdatingAtPath: filePath)
        Logger.general.info(category: "DeviceTransferDataWriter", message: "Open file: \(filePath)")
    }

    private func readAndParseRecordData() {
        assert(queue.isCurrent)
        guard !pendingParsedRecordPath.isEmpty else {
            return
        }
        let filePath = pendingParsedRecordPath.removeFirst()
        let fileHandle: FileHandle
        do {
            fileHandle = try FileHandle(forReadingFrom: filePath)
        } catch {
            Logger.general.error(category: "DeviceTransferDataWriter", message: "Reading from \(filePath) failed: \(error)")
            return
        }
        Logger.general.info(category: "DeviceTransferDataWriter", message: "Parse file: \(filePath.path)")
        let fileSize = fileHandle.seekToEndOfFile()
        var offset: UInt64 = 0
        while offset < fileSize, canProcessData {
            autoreleasepool {
                fileHandle.seek(toFileOffset: offset)
                let lengthData = fileHandle.readData(ofLength: Int(DeviceTransferData.payloadLength))
                let length = Int(Int32(data: lengthData, endianess: .big))
                offset += DeviceTransferData.payloadLength
                fileHandle.seek(toFileOffset: offset)
                let data = fileHandle.readData(ofLength: Int(length))
                offset += UInt64(length)
                parseRecord(data: data)
                DispatchQueue.main.async {
                    self.parsedRecordCount += 1
                    guard let delegate = self.delegate else {
                        return
                    }
                    if self.parsedRecordCount >= self.totalRecordCount {
                        guard self.canProcessData else {
                            return
                        }
                        self.queue.async {
                            self.processFiles()
                            DispatchQueue.main.async {
                                delegate.deviceTransferDataWriter(self, update: 1)
                            }
                        }
                    } else {
                        let progress = Float(self.parsedRecordCount) / Float(self.totalRecordCount + 1)
                        delegate.deviceTransferDataWriter(self, update: progress)
                    }
                }
            }
        }
        fileHandle.closeFile()
        try? FileManager.default.removeItem(at: filePath)
        queue.async {
            self.readAndParseRecordData()
        }
    }
    
}

extension DeviceTransferDataWriter {
    
    private func parseRecord(data: Data) {
        assert(queue.isCurrent)
        do {
            struct TypeWrapper: Decodable {
                let type: DeviceTransferRecordType
            }
            
            let decoder = JSONDecoder.default
            let wrapper = try decoder.decode(TypeWrapper.self, from: data)
            switch wrapper.type {
            case .conversation:
                let conversation = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferConversation>.self, from: data).data
                ConversationDAO.shared.save(conversation: conversation.toConversation(from: remotePlatform))
            case .participant:
                let participant = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferParticipant>.self, from: data).data
                ParticipantDAO.shared.save(participant: participant.toParticipant())
            case .user:
                let user = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferUser>.self, from: data).data
                UserDAO.shared.save(user: user.toUser())
            case .app:
                let app = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferApp>.self, from: data).data
                AppDAO.shared.save(app: app.toApp())
            case .asset:
                let asset = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferAsset>.self, from: data).data
                AssetDAO.shared.save(asset: asset.toAsset())
            case .snapshot:
                let snapshot = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferSnapshot>.self, from: data).data
                SnapshotDAO.shared.save(snapshot: snapshot.toSnapshot())
            case .sticker:
                let sticker = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferSticker>.self, from: data).data
                StickerDAO.shared.save(sticker: sticker.toSticker())
            case .pinMessage:
                let pinMessage = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferPinMessage>.self, from: data).data
                PinMessageDAO.shared.save(pinMessage: pinMessage.toPinMessage())
            case .transcriptMessage:
                let transcriptMessage = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferTranscriptMessage>.self, from: data).data
                TranscriptMessageDAO.shared.save(transcriptMessage: transcriptMessage.toTranscriptMessage())
            case .message:
                let message = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferMessage>.self, from: data).data
                if MessageCategory.isLegal(category: message.category) {
                    MessageDAO.shared.save(message: message.toMessage())
                } else {
                    Logger.general.warn(category: "DeviceTransferDataWriter", message: "Message is illegal: \(message)")
                }
            case .messageMention:
                let messageMention = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferMessageMention>.self, from: data).data
                if let mention = messageMention.toMessageMention() {
                    MessageMentionDAO.shared.save(messageMention: mention)
                } else {
                    Logger.general.warn(category: "DeviceTransferDataWriter", message: "Message Mention does not exist: \(messageMention)")
                }
            case .expiredMessage:
                let expiredMessage = try decoder.decode(DeviceTransferTypedRecord<DeviceTransferExpiredMessage>.self, from: data).data
                ExpiredMessageDAO.shared.save(expiredMessage: expiredMessage.toExpiredMessage())
            }
        } catch {
            let content = String(data: data, encoding: .utf8) ?? "Data(\(data.count))"
            Logger.general.error(category: "DeviceTransferDataWriter", message: "Error: \(error) Content: \(content)")
        }
    }
    
    private func processFiles() {
        assert(queue.isCurrent)
        guard
            let fileEnumerator = FileManager.default.enumerator(at: DeviceTransferData.file.url(name: nil),
                                                                includingPropertiesForKeys: [.isRegularFileKey],
                                                                options: [.skipsHiddenFiles, .skipsPackageDescendants])
        else {
            Logger.general.error(category: "DeviceTransferDataWriter", message: "Can't create file enumerator")
            return
        }
        Logger.general.info(category: "DeviceTransferDataWriter", message: "Start processing files")
        let fileManager = FileManager.default
        for case let fileURL as URL in fileEnumerator {
            let components = fileURL.lastPathComponent.components(separatedBy: ".")
            guard components.count == 2, let id = components.first else {
                Logger.general.info(category: "DeviceTransferDataWriter", message: "Invalid file url: \(fileURL.path)")
                continue
            }
            var destinationURLs: [URL]
            if let message = MessageDAO.shared.getMessage(messageId: id), let mediaURL = message.mediaUrl {
                guard let category = AttachmentContainer.Category(messageCategory: message.category) else {
                    Logger.general.error(category: "DeviceTransferDataWriter", message: "Invalid category: \(message.category)")
                    continue
                }
                let url = AttachmentContainer.url(for: category, filename: mediaURL)
                destinationURLs = [url]
                if let transcriptMessage = TranscriptMessageDAO.shared.transcriptMessage(messageId: id), let mediaURL = transcriptMessage.mediaUrl {
                    let url = AttachmentContainer.url(transcriptId: transcriptMessage.transcriptId, filename: mediaURL)
                    destinationURLs.append(url)
                }
            } else if let transcriptMessage = TranscriptMessageDAO.shared.transcriptMessage(messageId: id), let mediaURL = transcriptMessage.mediaUrl {
                let url = AttachmentContainer.url(transcriptId: transcriptMessage.transcriptId, filename: mediaURL)
                destinationURLs = [url]
            } else {
                Logger.general.warn(category: "DeviceTransferDataWriter", message: "No message found for: \(id)")
                continue
            }
            for destinationURL in destinationURLs {
                do {
                    if fileManager.fileExists(atPath: destinationURL.path) {
                        try fileManager.removeItem(at: destinationURL)
                    }
                    try fileManager.copyItem(at: fileURL, to: destinationURL)
                } catch {
                    Logger.general.error(category: "DeviceTransferDataWriter", message: "\(id) move failed: \(error)")
                }
            }
        }
        try? FileManager.default.removeItem(atPath: DeviceTransferData.url().path)
    }
    
}
