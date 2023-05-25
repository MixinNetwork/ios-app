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
    private let fileSize: Int
    private let fileManager: FileManager = .default
    private let key: Data
    
    private var localHMAC: HMACSHA256
    private var decryptor: AESCryptor
    private var remoteHMAC = Data(capacity: DeviceTransferProtocol.hmacDataCount)
    private var consumedEncryptedDataCount = 0
    
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
            self.fileSize = Int(context.header.length) - DeviceTransferProtocol.ivDataCount - idData.count
            self.key = key.aes
            self.localHMAC = HMACSHA256(key: key.hmac)
            self.decryptor = decryptor
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
        let remainingCount = fileSize - consumedEncryptedDataCount
        if remainingCount == 0 {
            remoteHMAC.append(data)
        } else if data.count >= remainingCount {
            let encryptedFileData = data.prefix(remainingCount)
            localHMAC.update(data: encryptedFileData)
            
            let decryptedFileData = try decryptor.update(encryptedFileData)
            handle.write(decryptedFileData)
            
            consumedEncryptedDataCount = fileSize
            
            let hmacSliceCount = data.count - remainingCount
            if hmacSliceCount > 0 {
                let hmacSliceData = data.suffix(hmacSliceCount)
                remoteHMAC.append(hmacSliceData)
            }
        } else {
            localHMAC.update(data: data)
            
            let decrypted = try decryptor.update(data)
            handle.write(decrypted)
            
            consumedEncryptedDataCount += data.count
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
        if localHMAC != remoteHMAC {
            let local = localHMAC.base64EncodedString()
            let remote = remoteHMAC.base64EncodedString()
            Logger.general.error(category: "DeviceTransferFileStream", message: "\(id) Local HMAC: \(local), Remote HMAC: \(remote)")
        } else {
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
    
}
