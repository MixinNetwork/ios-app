import Foundation
import MixinServices

fileprivate let fileManager = FileManager.default

final class DeviceTransferMessageProcessor {
    
    // This class is not thread safe to achieve best performance within a niche usage
    // To avoid data racing, always call `process(message:)`, `finishProcessing` in strict order
    
    enum ProcessingError: Error {
        case createInputStream
        case readInputStream(Error?)
    }
    
    private enum ReadStreamResult {
        case success
        case endOfStream
        case operationFailed(Error?)
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
    
    init(remotePlatform: DeviceTransferPlatform, cacheContainerURL: URL, inputQueue: Queue) {
        self.remotePlatform = remotePlatform
        self.cacheContainerURL = cacheContainerURL
        self.inputQueue = inputQueue
        pthread_rwlock_init(&cancellationLock, nil)
    }
    
    func process(message: Data) throws {
        assert(inputQueue.isCurrent)
        
        let cache: Cache
        if let writingCache {
            cache = writingCache
        } else {
            Logger.general.info(category: "DeviceTransferMessageProcessor", message: "Create cache 0")
            cache = try Cache(index: 0, containerURL: cacheContainerURL)
            writingCache = cache
        }
        
        let length = Cache.MessageLength(message.count).data(endianness: .little)
        cache.handle.write(length)
        cache.wroteCount += length.count
        cache.handle.write(message)
        cache.wroteCount += message.count
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
            if !self.pendingMessages.isEmpty {
                if self.isCancelled {
                    Logger.general.info(category: "DeviceTransferMessageProcessor", message: "Cancelled on finish processing")
                } else {
                    MessageDAO.shared.save(messages: self.pendingMessages)
                    self.pendingMessages.removeAll(keepingCapacity: false)
                    Logger.general.info(category: "DeviceTransferMessageProcessor", message: "All pending messages are saved")
                }
            }
            self.processFiles()
            DispatchQueue.main.async {
                self.progress = 1
            }
        }
    }
    
    func cancel() {
        Logger.general.info(category: "DeviceTransferMessageProcessor", message: "Cancelled")
        isCancelled = true
    }
    
}

extension DeviceTransferMessageProcessor {
    
    private func reportProgress() {
        assert(processingQueue.isCurrent)
        let progress = Float(processedCount) / Float(totalCount)
        DispatchQueue.main.async {
            self.progress = progress
        }
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
        return .success
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
    streamReadingLoop:
        while stream.hasBytesAvailable {
            guard !isCancelled else {
                Logger.general.info(category: "DeviceTransferMessageProcessor", message: "Not processing cache \(cache.index) by cancellation")
                return
            }
            
            let length: Int
            switch read(from: stream, to: &cacheReadingBuffer, length: Cache.messageLengthLayoutSize) {
            case .endOfStream:
                break streamReadingLoop
            case .operationFailed(let error):
                processingError = .readInputStream(error)
                return
            case .success:
                length = Int(Cache.MessageLength(data: cacheReadingBuffer, endianess: .little))
            }
            
            if cacheReadingBuffer.count < length {
                cacheReadingBuffer.count = length
            }
            switch read(from: stream, to: &cacheReadingBuffer, length: length) {
            case .endOfStream:
                assertionFailure("Impossible")
                Logger.general.error(category: "DeviceTransferMessageProcessor", message: "EOS after length is read")
            case .operationFailed(let error):
                processingError = .readInputStream(error)
                return
            case .success:
                let content = cacheReadingBuffer[cacheReadingBuffer.startIndex..<cacheReadingBuffer.startIndex.advanced(by: length)]
                let numberOfAttachments = process(jsonData: content)
                totalCount += numberOfAttachments
                processedCount += 1
                if processedCount - processedCountOnLastProgressReporting == progressReportingInterval {
                    processedCountOnLastProgressReporting = processedCount
                    reportProgress()
                }
            }
        }
        
        guard !isCancelled else {
            Logger.general.info(category: "DeviceTransferMessageProcessor", message: "Not processing cache \(cache.index) by cancellation")
            return
        }
        reportProgress()
        Logger.general.info(category: "DeviceTransferMessageProcessor", message: "End processing cache \(cache.index)")
    }
    
    // Return number of attachments
    private func process(jsonData: Data) -> Int {
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
                return 0
            case .participant:
                let participant = try decoder.decode(DataWrapper<DeviceTransferParticipant>.self, from: jsonData).data
                ParticipantDAO.shared.save(participant: participant.toParticipant())
                return 0
            case .user:
                let user = try decoder.decode(DataWrapper<DeviceTransferUser>.self, from: jsonData).data
                UserDAO.shared.save(user: user.toUser())
                return 0
            case .app:
                let app = try decoder.decode(DataWrapper<DeviceTransferApp>.self, from: jsonData).data
                AppDAO.shared.save(app: app.toApp())
                return 0
            case .asset:
                let asset = try decoder.decode(DataWrapper<DeviceTransferAsset>.self, from: jsonData).data
                AssetDAO.shared.save(asset: asset.toAsset())
                return 0
            case .snapshot:
                let snapshot = try decoder.decode(DataWrapper<DeviceTransferSnapshot>.self, from: jsonData).data
                SnapshotDAO.shared.save(snapshot: snapshot.toSnapshot())
                return 0
            case .sticker:
                let sticker = try decoder.decode(DataWrapper<DeviceTransferSticker>.self, from: jsonData).data
                StickerDAO.shared.save(sticker: sticker.toSticker())
                return 0
            case .pinMessage:
                let pinMessage = try decoder.decode(DataWrapper<DeviceTransferPinMessage>.self, from: jsonData).data
                PinMessageDAO.shared.save(pinMessage: pinMessage.toPinMessage())
                return 0
            case .transcriptMessage:
                let transcriptMessage = try decoder.decode(DataWrapper<DeviceTransferTranscriptMessage>.self, from: jsonData).data
                TranscriptMessageDAO.shared.save(transcriptMessage: transcriptMessage.toTranscriptMessage())
                if transcriptMessage.mediaUrl.isNilOrEmpty {
                    return 0
                } else {
                    return 1
                }
            case .message:
                let message = try decoder.decode(DataWrapper<DeviceTransferMessage>.self, from: jsonData).data
                if MessageCategory.isLegal(category: message.category) {
                    pendingMessages.append(message.toMessage())
                    if pendingMessages.count == messageSavingBatchCount {
                        MessageDAO.shared.save(messages: pendingMessages)
                        pendingMessages.removeAll(keepingCapacity: true)
                    }
                    if message.mediaUrl.isNilOrEmpty {
                        return 0
                    } else {
                        return 1
                    }
                } else {
                    Logger.general.warn(category: "DeviceTransferMessageProcessor", message: "Message is illegal: \(message)")
                    return 0
                }
            case .messageMention:
                let messageMention = try decoder.decode(DataWrapper<DeviceTransferMessageMention>.self, from: jsonData).data
                if let mention = messageMention.toMessageMention() {
                    MessageMentionDAO.shared.save(messageMention: mention)
                } else {
                    Logger.general.warn(category: "DeviceTransferMessageProcessor", message: "Message Mention does not exist: \(messageMention)")
                }
                return 0
            case .expiredMessage:
                let expiredMessage = try decoder.decode(DataWrapper<DeviceTransferExpiredMessage>.self, from: jsonData).data
                ExpiredMessageDAO.shared.save(expiredMessage: expiredMessage.toExpiredMessage())
                return 0
            }
        } catch {
            let content = String(data: jsonData, encoding: .utf8) ?? "Data(\(jsonData.count))"
            Logger.general.error(category: "DeviceTransferMessageProcessor", message: "Error: \(error) Content: \(content)")
            return 0
        }
    }
    
    private func processFiles() {
        assert(processingQueue.isCurrent)
        guard let fileEnumerator = fileManager.enumerator(at: cacheContainerURL, includingPropertiesForKeys: nil) else {
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
            
            processedCount += destinationURLs.count
            if processedCount - processedCountOnLastProgressReporting == progressReportingInterval {
                processedCountOnLastProgressReporting = processedCount
                reportProgress()
            }
            
            try? fileManager.removeItem(at: fileURL)
        }
    }
    
}
