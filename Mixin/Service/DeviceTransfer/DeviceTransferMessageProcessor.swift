import Foundation
import MixinServices

fileprivate let fileManager = FileManager.default

final class DeviceTransferMessageProcessor {
    
    // This class is not thread safe to achieve best performance within a niche usage
    // To avoid data racing, always call `process(message:)`, `finishProcessing` in strict order
    
    enum ProcessingError: Error {
        case createInputStream
        case readInputStream(Error?)
        case mismatchedLengthRead(required: Int, read: Int)
        case enumerateFiles
    }
    
    private class Cache {
        
        typealias MessageLength = UInt32
        
        static let maxCount = 10 * Int(bytesPerMegaByte)
        static let messageLengthLayoutSize = 4
        
        let index: UInt
        let url: URL
        let handle: FileHandle
        
        var wroteCount: Int = 0
        
        var isOversized: Bool {
            wroteCount >= Self.maxCount
        }
        
        init(index: UInt, containerURL: URL) throws {
            let url = containerURL.appendingPathComponent(String(index) + ".cache")
            try Data().write(to: url)
            self.index = index
            self.url = url
            self.handle = try FileHandle(forWritingTo: url)
        }
        
    }
    
    @Published private(set) var progress: Float = 0
    @Published private(set) var processingError: ProcessingError?
    
    private let key: Data
    private let remotePlatform: DeviceTransferPlatform
    private let cacheContainerURL: URL
    private let inputQueue: Queue
    private let processingQueue = Queue(label: "one.mixin.messenger.DeviceTransferMessageProcessor")
    private let messageSavingBatchCount = 100
    private let progressReportingInterval = 10 // Update progress every 10 items are processed
    
    // https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/pthread_rwlock_wrlock.3.html#//apple_ref/doc/man/3/pthread_rwlock_wrlock
    // To prevent writer starvation, writers are favored over readers.
    private var cancellationLock = pthread_rwlock_t()
    private var _cancelled = false
    private var isCancelled: Bool {
        get {
            pthread_rwlock_rdlock(&self.cancellationLock)
            let cancelled = _cancelled
            pthread_rwlock_unlock(&self.cancellationLock)
            return cancelled
        }
        set {
            pthread_rwlock_wrlock(&cancellationLock)
            _cancelled = newValue
            pthread_rwlock_unlock(&cancellationLock)
        }
    }
    
    private var totalCount = 0
    private var processedCount = 0
    
    private var writingCache: Cache?
    
    private var cacheReadingBuffer = Data(count: Int(bytesPerKiloByte))
    
    // Messages are saved to database in batch. See `messageSavingBatchCount`
    private var pendingMessages: [Message] = []
    
    init(key: Data, remotePlatform: DeviceTransferPlatform, cacheContainerURL: URL, inputQueue: Queue) {
        self.key = key
        self.remotePlatform = remotePlatform
        self.cacheContainerURL = cacheContainerURL
        self.inputQueue = inputQueue
        pthread_rwlock_init(&cancellationLock, nil)
    }
    
    func process(encryptedMessage: Data) throws {
        assert(inputQueue.isCurrent)
        
        let cache: Cache
        if let writingCache {
            cache = writingCache
        } else {
            Logger.general.info(category: "DeviceTransferMessageProcessor", message: "Create cache 0")
            cache = try Cache(index: 0, containerURL: cacheContainerURL)
            writingCache = cache
        }
        
        let length = Cache.MessageLength(encryptedMessage.count).data(endianness: .little)
        cache.handle.write(length)
        cache.wroteCount += length.count
        cache.handle.write(encryptedMessage)
        cache.wroteCount += encryptedMessage.count
        processingQueue.async {
            self.totalCount += 1
        }
        
        if cache.isOversized {
            cache.handle.closeFile()
            processingQueue.async {
                self.process(cache: cache)
                try? fileManager.removeItem(at: cache.url)
            }
            let nextIndex = cache.index + 1
            Logger.general.info(category: "DeviceTransferMessageProcessor", message: "Create cache \(nextIndex)")
            writingCache = try Cache(index: nextIndex, containerURL: cacheContainerURL)
        }
    }
    
    func reportFileReceived() {
        processingQueue.async {
            self.totalCount += 1
        }
    }
    
    func finishProcessing() {
        assert(inputQueue.isCurrent)
        guard let lastCache = writingCache else {
            Logger.general.info(category: "DeviceTransferMessageProcessor", message: "All pending messages are saved")
            return
        }
        writingCache = nil
        lastCache.handle.closeFile()
        processingQueue.async {
            self.process(cache: lastCache)
            try? fileManager.removeItem(at: lastCache.url)
            self.savePendingMessages()
            self.processFiles()
            self.progress = 1
        }
    }
    
    func cancel() {
        Logger.general.info(category: "DeviceTransferMessageProcessor", message: "Cancelled")
        isCancelled = true
    }
    
}

// MARK: - Cache Processing
extension DeviceTransferMessageProcessor {
    
    private func reportProgress() {
        assert(processingQueue.isCurrent)
        // Divide the count as integer to prevent `progress` from rounding when counts are large
        let progress = Float(processedCount * 100 / totalCount) / 100
        self.progress = progress
    }
    
    private func savePendingMessages() {
        guard !pendingMessages.isEmpty else {
            return
        }
        MessageDAO.shared.save(messages: pendingMessages)
        pendingMessages.removeAll(keepingCapacity: false)
        Logger.general.info(category: "DeviceTransferMessageProcessor", message: "All pending messages are saved")
    }
    
    private func process(cache: Cache) {
        assert(processingQueue.isCurrent)
        guard !isCancelled else {
            Logger.general.info(category: "DeviceTransferMessageProcessor", message: "Not processing cache \(cache.index) by cancellation")
            return
        }
        
        guard let stream = InputStream(url: cache.url) else {
            processingError = .createInputStream
            return
        }
        stream.open()
        defer {
            stream.close()
        }
        
        Logger.general.info(category: "DeviceTransferMessageProcessor", message: "Begin processing cache \(cache.index)")
        var processedCountOnLastProgressReporting = self.processedCount
        while stream.hasBytesAvailable {
            guard !isCancelled else {
                Logger.general.info(category: "DeviceTransferMessageProcessor", message: "Not processing cache \(cache.index) by cancellation")
                return
            }
            
            let requiredLength: Int
            switch read(from: stream, to: &cacheReadingBuffer, length: Cache.messageLengthLayoutSize) {
            case .endOfStream:
                if isCancelled {
                    Logger.general.info(category: "DeviceTransferMessageProcessor", message: "End processing cache \(cache.index) with cancellation")
                } else {
                    reportProgress()
                    Logger.general.info(category: "DeviceTransferMessageProcessor", message: "End processing cache \(cache.index)")
                }
                return
            case .operationFailed(let error):
                processingError = .readInputStream(error)
                return
            case .success:
                requiredLength = Int(Cache.MessageLength(data: cacheReadingBuffer, endianess: .little))
            }
            
            if cacheReadingBuffer.count < requiredLength {
                cacheReadingBuffer.count = requiredLength
            }
            switch read(from: stream, to: &cacheReadingBuffer, length: requiredLength) {
            case .endOfStream:
                assertionFailure("Impossible")
                Logger.general.error(category: "DeviceTransferMessageProcessor", message: "EOS after length is read")
                return
            case .operationFailed(let error):
                processingError = .readInputStream(error)
                return
            case .success(let readLength):
                guard requiredLength == readLength else {
                    Logger.general.error(category: "DeviceTransferMessageProcessor", message: "Error reading: \(readLength), required: \(requiredLength)")
                    processingError = .mismatchedLengthRead(required: requiredLength, read: readLength)
                    return
                }
                let encryptedData = cacheReadingBuffer[..<cacheReadingBuffer.startIndex.advanced(by: readLength)]
                do {
                    let decryptedData = try AESCryptor.decrypt(encryptedData, with: key)
                    process(jsonData: decryptedData)
                } catch {
                    Logger.general.error(category: "DeviceTransferMessageProcessor", message: "Decrypt failed: \(error)")
                }
                processedCount += 1
                if processedCount - processedCountOnLastProgressReporting == progressReportingInterval {
                    processedCountOnLastProgressReporting = processedCount
                    reportProgress()
                }
            }
        }
    }
    
}

// MARK: - Stream Reading
extension DeviceTransferMessageProcessor {
    
    private enum ReadStreamResult {
        case success(Int)
        case endOfStream
        case operationFailed(Error?)
    }
    
    private func read(from stream: InputStream, to buffer: inout Data, length: Int) -> ReadStreamResult {
        var totalBytesRead = 0
        while totalBytesRead < length {
            let bytesRead = buffer.withUnsafeMutableBytes { buffer in
                let pointer = buffer.baseAddress!.advanced(by: totalBytesRead)
                return stream.read(pointer, maxLength: length - totalBytesRead)
            }
            switch bytesRead {
            case 0:
                return .endOfStream
            case -1:
                return .operationFailed(stream.streamError)
            default:
                totalBytesRead += bytesRead
            }
        }
        return .success(totalBytesRead)
    }
    
}

// MARK: - Data Processing
extension DeviceTransferMessageProcessor {
    
    private func process(jsonData: Data) {
        struct TypeWrapper: Decodable {
            let type: DeviceTransferRecordType
        }
        struct DataWrapper<Record: DeviceTransferRecord>: Decodable {
            let data: Record
        }
        let decoder = JSONDecoder.default
        do {
            let type = try decoder.decode(TypeWrapper.self, from: jsonData).type
            switch type {
            case .conversation:
                let conversation = try decoder.decode(DataWrapper<DeviceTransferConversation>.self, from: jsonData).data
                ConversationDAO.shared.save(conversation: conversation.toConversation(from: remotePlatform))
            case .participant:
                let participant = try decoder.decode(DataWrapper<DeviceTransferParticipant>.self, from: jsonData).data
                ParticipantDAO.shared.save(participant: participant.toParticipant())
            case .user:
                let user = try decoder.decode(DataWrapper<DeviceTransferUser>.self, from: jsonData).data
                UserDAO.shared.save(user: user.toUser())
            case .app:
                let app = try decoder.decode(DataWrapper<DeviceTransferApp>.self, from: jsonData).data
                AppDAO.shared.save(app: app.toApp())
            case .asset:
                let asset = try decoder.decode(DataWrapper<DeviceTransferAsset>.self, from: jsonData).data
                AssetDAO.shared.save(asset: asset.toAsset())
            case .snapshot:
                let snapshot = try decoder.decode(DataWrapper<DeviceTransferSnapshot>.self, from: jsonData).data
                SnapshotDAO.shared.save(snapshot: snapshot.toSnapshot())
            case .sticker:
                let sticker = try decoder.decode(DataWrapper<DeviceTransferSticker>.self, from: jsonData).data
                StickerDAO.shared.save(sticker: sticker.toSticker())
            case .pinMessage:
                let pinMessage = try decoder.decode(DataWrapper<DeviceTransferPinMessage>.self, from: jsonData).data
                PinMessageDAO.shared.save(pinMessage: pinMessage.toPinMessage())
            case .transcriptMessage:
                let transcriptMessage = try decoder.decode(DataWrapper<DeviceTransferTranscriptMessage>.self, from: jsonData).data
                TranscriptMessageDAO.shared.save(transcriptMessage: transcriptMessage.toTranscriptMessage())
            case .message:
                let message = try decoder.decode(DataWrapper<DeviceTransferMessage>.self, from: jsonData).data
                if MessageCategory.isLegal(category: message.category) {
                    pendingMessages.append(message.toMessage())
                    if pendingMessages.count == messageSavingBatchCount {
                        MessageDAO.shared.save(messages: pendingMessages)
                        pendingMessages.removeAll(keepingCapacity: true)
                    }
                } else {
                    Logger.general.warn(category: "DeviceTransferMessageProcessor", message: "Message is illegal: \(message)")
                }
            case .messageMention:
                savePendingMessages()
                let messageMention = try decoder.decode(DataWrapper<DeviceTransferMessageMention>.self, from: jsonData).data
                if let mention = messageMention.toMessageMention() {
                    MessageMentionDAO.shared.save(messageMention: mention)
                } else {
                    Logger.general.warn(category: "DeviceTransferMessageProcessor", message: "Message Mention does not exist: \(messageMention)")
                }
            case .expiredMessage:
                savePendingMessages()
                let expiredMessage = try decoder.decode(DataWrapper<DeviceTransferExpiredMessage>.self, from: jsonData).data
                ExpiredMessageDAO.shared.save(expiredMessage: expiredMessage.toExpiredMessage())
            }
        } catch {
            let content = String(data: jsonData, encoding: .utf8) ?? "Data(\(jsonData.count))"
            Logger.general.error(category: "DeviceTransferMessageProcessor", message: "Error: \(error) Content: \(content)")
        }
    }
    
    private func processFiles() {
        assert(processingQueue.isCurrent)
        guard let fileEnumerator = fileManager.enumerator(at: cacheContainerURL, includingPropertiesForKeys: nil) else {
            processingError = .enumerateFiles
            Logger.general.error(category: "DeviceTransferMessageProcessor", message: "Can't create file enumerator")
            return
        }
        Logger.general.info(category: "DeviceTransferMessageProcessor", message: "Start processing files")
        var processedCountOnLastProgressReporting = processedCount
        
        for case let fileURL as URL in fileEnumerator {
            guard !isCancelled else {
                Logger.general.info(category: "DeviceTransferMessageProcessor", message: "Stop processing files by cancellation")
                return
            }
            let id = fileURL.lastPathComponent
            
            var destinationURLs: [URL] = []
            if let message = MessageDAO.shared.getMessage(messageId: id),
               let mediaURL = message.mediaUrl,
               let category = AttachmentContainer.Category(messageCategory: message.category)
            {
                let url = AttachmentContainer.url(for: category, filename: mediaURL)
                destinationURLs = [url]
            } else {
                destinationURLs = []
            }
            
            if let transcriptMessage = TranscriptMessageDAO.shared.transcriptMessage(messageId: id),
               let mediaURL = transcriptMessage.mediaUrl
            {
                let url = AttachmentContainer.url(transcriptId: transcriptMessage.transcriptId, filename: mediaURL)
                destinationURLs.append(url)
            }
            
            for destinationURL in destinationURLs {
                do {
                    if fileManager.fileExists(atPath: destinationURL.path) {
                        try fileManager.removeItem(at: destinationURL)
                    }
                    try fileManager.copyItem(at: fileURL, to: destinationURL)
                } catch {
                    Logger.general.error(category: "DeviceTransferMessageProcessor", message: "\(id) copy failed: \(error)")
                }
            }
            
            processedCount += 1
            if processedCount - processedCountOnLastProgressReporting == progressReportingInterval {
                processedCountOnLastProgressReporting = processedCount
                reportProgress()
            }
            
            try? fileManager.removeItem(at: fileURL)
        }
    }
    
}
