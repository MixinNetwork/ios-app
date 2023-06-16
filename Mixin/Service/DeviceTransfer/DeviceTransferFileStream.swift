import Foundation
import MixinServices

class DeviceTransferFileStream: InstanceInitializable {
    
    let id: UUID
    
    fileprivate init(id: UUID) {
        self.id = id
    }
    
    convenience init(context: DeviceTransferProtocol.FileContext, key: DeviceTransferKey, containerURL: URL) {
        if let impl = DeviceTransferFileStreamImpl(context, key: key, containerURL: containerURL) {
            self.init(instance: impl as! Self)
        } else {
            self.init(id: context.fileHeader.id)
        }
    }
    
    func write(data: Data) throws {
        
    }
    
    func close() throws {
        
    }
    
}

fileprivate final class DeviceTransferFileStreamImpl: DeviceTransferFileStream {
    
    private let handle: FileHandle
    private let fileManager: FileManager = .default
    
    private var decryptor: AESCryptor
    private var remainingDataCount: Int
    private var localHMAC: HMACSHA256
    private var remoteHMAC = Data(capacity: DeviceTransferProtocol.hmacDataCount)
    
    init?(_ context: DeviceTransferProtocol.FileContext, key: DeviceTransferKey, containerURL: URL) {
        let decryptor: AESCryptor
        do {
            decryptor = try AESCryptor(operation: .decrypt, iv: context.fileHeader.iv, key: key.aes)
        } catch {
            Logger.general.error(category: "DeviceTransferFileStream", message: "Failed to init cryptor: \(error)")
            return nil
        }
        
        let id = context.fileHeader.id.uuidString.lowercased()
        let idData = context.fileHeader.id.data
        
        do {
            let fileURL = containerURL.appendingPathComponent(id)
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            fileManager.createFile(atPath: fileURL.path, contents: nil)
            
            self.handle = try FileHandle(forWritingTo: fileURL)
            self.decryptor = decryptor
            self.remainingDataCount = Int(context.header.length) - idData.count - DeviceTransferProtocol.ivDataCount
            self.localHMAC = HMACSHA256(key: key.hmac)
            super.init(id: context.fileHeader.id)
            
            localHMAC.update(data: idData)
            localHMAC.update(data: context.fileHeader.iv)
        } catch {
            Logger.general.error(category: "DeviceTransferFileStream", message: error.localizedDescription)
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
    
    override func close() throws {
        do {
            let finalData = try decryptor.finalize()
            handle.write(finalData)
            try handle.close()
        } catch {
            Logger.general.error(category: "DeviceTransferFileStream", message: "\(id) Close: \(error)")
        }
        
        let localHMAC = localHMAC.finalize()
        guard localHMAC == remoteHMAC else {
            let local = localHMAC.base64EncodedString()
            let remote = remoteHMAC.base64EncodedString()
            Logger.general.error(category: "DeviceTransferFileStream", message: "\(id) Local HMAC: \(local), Remote HMAC: \(remote)")
            throw DeviceTransferError.mismatchedHMAC(local: localHMAC, remote: remoteHMAC)
        }
        #if DEBUG
        Logger.general.debug(category: "DeviceTransferFileStream", message: "\(id) Closed")
        #endif
    }
    
}
