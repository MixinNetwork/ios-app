import Foundation
import MixinServices

class DeviceTransferFileStream: InstanceInitializable {
    
    let id: UUID
    
    fileprivate init(id: UUID) {
        self.id = id
    }
    
    convenience init(context: DeviceTransferProtocol.FileContext) {
        if let impl = DeviceTransferFileStreamImpl(context) {
            self.init(instance: impl as! Self)
        } else {
            self.init(id: context.id)
        }
    }
    
    func write(data: Data) {
        
    }
    
    func close() {
        
    }
    
}

fileprivate final class DeviceTransferFileStreamImpl: DeviceTransferFileStream {
    
    private let tempURL: URL
    private let handle: FileHandle
    private let destinationURLs: [URL]
    private let fileSize: Int
    private let fileManager: FileManager = .default
    
    private var wroteCount = 0
    private var localChecksum = CRC32()
    private var remoteChecksumSlice = Data()
    
    init?(_ context: DeviceTransferProtocol.FileContext) {
        let id = context.id.uuidString.lowercased()
        let idData = context.id.data
        
        var destinationURLs: [URL]
        if let message = MessageDAO.shared.getMessage(messageId: id), let mediaURL = message.mediaUrl {
            let category = AttachmentContainer.Category(messageCategory: message.category) ?? .files
            let url = AttachmentContainer.url(for: category, filename: mediaURL)
            destinationURLs = [url]
            if let transcriptMessage = TranscriptMessageDAO.shared.transcriptMessage(messageId: id), let mediaURL = transcriptMessage.mediaUrl {
                let url = AttachmentContainer.url(transcriptId: transcriptMessage.transcriptId, filename: mediaURL)
                destinationURLs.append(url)
            }
        } else if let transcriptMessage = TranscriptMessageDAO.shared.transcriptMessage(messageId: id), let mediaURL = transcriptMessage.mediaUrl {
            let url = AttachmentContainer.url(transcriptId: id, filename: mediaURL)
            destinationURLs = [url]
        } else {
            return nil
        }
        
        do {
            let url = fileManager.temporaryDirectory.appendingPathComponent("devicetransfer.temp")
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
            fileManager.createFile(atPath: url.path, contents: nil)
            
            self.tempURL = url
            self.handle = try FileHandle(forWritingTo: url)
            self.destinationURLs = destinationURLs
            self.fileSize = Int(context.header.length) - idData.count
            super.init(id: context.id)
            localChecksum.update(data: idData)
        } catch {
            Logger.general.debug(category: "DeviceTransferFileStream", message: error.localizedDescription)
            assertionFailure()
            return nil
        }
    }
    
    override func write(data: Data) {
        let remainingFileDataCount = fileSize - wroteCount
        if remainingFileDataCount == 0 {
            remoteChecksumSlice.append(data)
        } else if data.count >= remainingFileDataCount {
            let fileData = data.prefix(remainingFileDataCount)
            handle.write(fileData)
            localChecksum.update(data: fileData)
            
            let checksumSliceCount = data.count - remainingFileDataCount
            if checksumSliceCount > 0 {
                let checksumSliceData = data.suffix(checksumSliceCount)
                remoteChecksumSlice.append(checksumSliceData)
            }
            
            wroteCount = fileSize
        } else {
            handle.write(data)
            localChecksum.update(data: data)
            wroteCount += data.count
        }
    }
    
    override func close() {
        if remoteChecksumSlice.count != DeviceTransferProtocol.checksumLength {
            Logger.general.error(category: "DeviceTransferFileStream", message: "\(id) Invalid checksum count: \(remoteChecksumSlice.count)")
        } else {
            let remoteChecksum = UInt64(data: remoteChecksumSlice, endianess: .big)
            if localChecksum.finalize() != remoteChecksum {
                Logger.general.error(category: "DeviceTransferFileStream", message: "\(id) Local checksum: \(localChecksum), Remote checksum: \(remoteChecksum)")
            } else {
                do {
                    try handle.close()
                    Logger.general.debug(category: "DeviceTransferFileStream", message: "\(id) Closed")
                    for destinationURL in destinationURLs {
                        let path = destinationURL.path
                        if fileManager.fileExists(atPath: path) {
                            if fileManager.fileSize(path) == 0 {
                                try? fileManager.removeItem(atPath: path)
                            } else {
                                continue
                            }
                        }
                        try fileManager.copyItem(at: tempURL, to: destinationURL)
                    }
                } catch {
                    Logger.general.error(category: "DeviceTransferFileStream", message: "\(id) error: \(error)")
                }
            }
        }
        try? fileManager.removeItem(at: tempURL)
    }
    
}
