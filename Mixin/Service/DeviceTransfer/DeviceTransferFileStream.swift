import Foundation
import MixinServices

class DeviceTransferFileStream: InstanceInitializable {
    
    let id: UUID
    
    fileprivate init(id: UUID) {
        self.id = id
    }
    
    convenience init(context: DeviceTransferProtocol.FileContext, key: DeviceTransferKey) {
        if let impl = DeviceTransferFileStreamImpl(context, key: key) {
            self.init(instance: impl as! Self)
        } else {
            self.init(id: context.fileHeader.id)
        }
    }
    
    func write(data: Data) throws {
        
    }
    
    func close() {
        
    }
    
}

fileprivate final class DeviceTransferFileStreamImpl: DeviceTransferFileStream {
    
    private let tempURL: URL
    private let handle: FileHandle
    private let destinationURLs: [URL]
    private let fileManager: FileManager = .default
    
    private var decryptor: AESCryptor
    private var remainingDataCount: Int
    private var localHMAC: HMACSHA256
    private var remoteHMAC = Data(capacity: DeviceTransferProtocol.hmacDataCount)
    
    init?(_ context: DeviceTransferProtocol.FileContext, key: DeviceTransferKey) {
        let decryptor: AESCryptor
        do {
            decryptor = try AESCryptor(operation: .decrypt, iv: context.fileHeader.iv, key: key.aes)
        } catch {
            Logger.general.error(category: "DeviceTransferFileStream", message: "Failed to init cryptor: \(error)")
            return nil
        }
        
        let id = context.fileHeader.id.uuidString.lowercased()
        let idData = context.fileHeader.id.data
        
        var destinationURLs: [URL]
        if let message = MessageDAO.shared.getMessage(messageId: id), let mediaURL = message.mediaUrl {
            guard let category = AttachmentContainer.Category(messageCategory: message.category) else {
                Logger.general.error(category: "DeviceTransferFileStream", message: "Invalid category: \(message.category)")
                return nil
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
            Logger.general.warn(category: "DeviceTransferFileStream", message: "No message found for: \(id)")
            return nil
        }
        
        do {
            let tempURL = fileManager.temporaryDirectory.appendingPathComponent("devicetransfer.tmp")
            if fileManager.fileExists(atPath: tempURL.path) {
                try fileManager.removeItem(at: tempURL)
            }
            fileManager.createFile(atPath: tempURL.path, contents: nil)
            
            self.tempURL = tempURL
            self.handle = try FileHandle(forWritingTo: tempURL)
            self.destinationURLs = destinationURLs
            self.decryptor = decryptor
            self.remainingDataCount = Int(context.header.length) - idData.count - DeviceTransferProtocol.ivDataCount
            self.localHMAC = HMACSHA256(key: key.hmac)
            super.init(id: context.fileHeader.id)
            
            localHMAC.update(data: idData)
            localHMAC.update(data: context.fileHeader.iv)
        } catch {
            Logger.general.debug(category: "DeviceTransferFileStream", message: error.localizedDescription)
            assertionFailure()
            return nil
        }
    }
    
    override func write(data: Data) throws {
        if remainingDataCount == 0 {
            remoteHMAC.append(data)
        } else if data.count >= remainingDataCount {
            let encryptedFileData = data.prefix(remainingDataCount)
            localHMAC.update(data: encryptedFileData)
            
            let decryptedFileData = try decryptor.update(encryptedFileData)
            handle.write(decryptedFileData)
            
            let hmacSliceCount = data.count - remainingDataCount
            if hmacSliceCount > 0 {
                let hmacSliceData = data.suffix(hmacSliceCount)
                remoteHMAC.append(hmacSliceData)
            }
            
            remainingDataCount = 0
        } else {
            localHMAC.update(data: data)
            
            let decrypted = try decryptor.update(data)
            handle.write(decrypted)
            
            remainingDataCount -= data.count
        }
    }
    
    override func close() {
        defer {
            try? fileManager.removeItem(at: tempURL)
        }
        
        do {
            let finalData = try decryptor.finalize()
            handle.write(finalData)
            try handle.close()
        } catch {
            Logger.general.error(category: "DeviceTransferFileStream", message: "\(id) Close: \(error)")
        }
        
        guard remoteHMAC.count == DeviceTransferProtocol.hmacDataCount else {
            Logger.general.error(category: "DeviceTransferFileStream", message: "\(id) Invalid HMAC: \(remoteHMAC.count)")
            return
        }
        let localHMAC = localHMAC.finalize()
        guard localHMAC == remoteHMAC else {
            let local = localHMAC.base64EncodedString()
            let remote = remoteHMAC.base64EncodedString()
            Logger.general.error(category: "DeviceTransferFileStream", message: "\(id) Local HMAC: \(local), Remote HMAC: \(remote)")
            return
        }
        
        for destinationURL in destinationURLs {
            let path = destinationURL.path
            if fileManager.fileExists(atPath: path) {
                if fileManager.fileSize(path) == 0 {
                    try? fileManager.removeItem(atPath: path)
                } else {
                    continue
                }
            }
            do {
                try fileManager.copyItem(at: tempURL, to: destinationURL)
            } catch {
                Logger.general.error(category: "DeviceTransferFileStream", message: "\(id) Not copied: \(error)")
            }
        }
    }
    
}
