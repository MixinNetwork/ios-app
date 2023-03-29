import Foundation
import MixinServices

protocol DeviceTransferDataParserDelegate: AnyObject {
    
    func deviceTransferDataParser(_ parser: DeviceTransferDataParser, didParseCommand command: DeviceTransferCommand)
    func deviceTransferDataParser(_ parser: DeviceTransferDataParser, didParseMessage message: Data)
    func deviceTransferDataParser(_ parser: DeviceTransferDataParser, didParseFile fileURL: URL)
    func deviceTransferDataParser(_ parser: DeviceTransferDataParser, didParseFailed error: DeviceTransferDataParserError)
    
}

enum DeviceTransferDataParserError: Error {
    case unknownType
    case mismatchedChecksum
}

class DeviceTransferDataParser {

    weak var delegate: DeviceTransferDataParserDelegate?
    
    private enum ByteLength {
        static let type = 1
        static let payloadLength = 4
        static let checksum = 8
        static let fileMessageID = 16
    }
    
    private enum BufferState {
        case empty
        case receivingMessage
        case receivingFile(ReceiveFileState)
        case failed
    }
    
    private enum ReceiveFileState {
        case header
        case content(handle: FileHandle?, fileURL: URL?, copyToURL: URL?, remainingLength: Int, checksum: CRC32)
        case checksum(fileURL: URL?, copyToURL: URL?, localChecksum: UInt64, remoteChecksumDataSlice: Data)
    }
    
    private var buffer = Data(capacity: 16)
    private var bufferState: BufferState = .empty
    
    func parse(_ data: Data) {
        switch bufferState {
        case .empty:
            appendTypeUndeterminedDataAndContinue(data)
        case .receivingMessage:
            buffer.append(data)
            continueWithMessage()
        case let .receivingFile(state):
            buffer.append(data)
            continueWithFile(state: state)
        case .failed:
            break
        }
    }
    
}

extension DeviceTransferDataParser {
    
    private func decodeMessageData(_ messageData: Data) {
        if let message = String(data: messageData, encoding: .utf8) {
            Logger.general.debug(category: "DeviceTransferDataParse", message: "Receive: \(message) \n")
        } else {
            Logger.general.debug(category: "DeviceTransferDataParse", message: "Receive: \(messageData) \n")
        }
        if let command = try? JSONDecoder.default.decode(DeviceTransferData<DeviceTransferCommand>.self, from: messageData).data {
            delegate?.deviceTransferDataParser(self, didParseCommand: command)
        } else {
            delegate?.deviceTransferDataParser(self, didParseMessage: messageData)
        }
    }
    
    private func appendTypeUndeterminedDataAndContinue(_ data: Data) {
        assert({
            switch bufferState {
            case .empty:
                return true
            default:
                return false
            }
        }())
        if let type = DeviceTransferDataType(rawValue: data[data.startIndex]) {
            buffer.append(data)
            switch type {
            case .message, .command:
                bufferState = .receivingMessage
                continueWithMessage()
            case .file:
                bufferState = .receivingFile(.header)
                continueWithFile(state: .header)
            }
        } else {
            delegate?.deviceTransferDataParser(self, didParseFailed: .unknownType)
        }
    }
    
    private func continueWithMessage() {
        /*
         |Message|
         |Type|Length|  Data |Checksum|
         */
        guard buffer.count > ByteLength.type + ByteLength.payloadLength + ByteLength.checksum else {
            return
        }
        let messageLength = {
            let startIndex = buffer.startIndex.advanced(by: ByteLength.type)
            let endIndex = buffer.startIndex.advanced(by: ByteLength.type + ByteLength.payloadLength)
            let data = buffer[startIndex..<endIndex]
            return Int(Int32(data: data, endianess: .big))
        }()
        guard buffer.count >= ByteLength.type + ByteLength.payloadLength + messageLength + ByteLength.checksum else {
            return
        }
        let messageData = {
            let startIndex = buffer.startIndex.advanced(by: ByteLength.type + ByteLength.payloadLength)
            let endIndex = buffer.startIndex.advanced(by: ByteLength.type + ByteLength.payloadLength + messageLength)
            return buffer[startIndex..<endIndex]
        }()
        let remoteChecksum = {
            let startIndex = buffer.startIndex.advanced(by: ByteLength.type + ByteLength.payloadLength + messageLength)
            let endIndex = buffer.startIndex.advanced(by: ByteLength.type + ByteLength.payloadLength + messageLength + ByteLength.checksum)
            let data = buffer[startIndex..<endIndex]
            return UInt64(data: data, endianess: .big)
        }()
        let localChecksum = CRC32.checksum(data: messageData)
        guard localChecksum == remoteChecksum else {
            bufferState = .failed
            Logger.general.debug(category: "DeviceTransferDataParser", message: "❌Checksum incorrect: remote:\(remoteChecksum) local:\(localChecksum) buffer: \(buffer.debugDescription)")
            delegate?.deviceTransferDataParser(self, didParseFailed: .mismatchedChecksum)
            return
        }
        
        decodeMessageData(messageData)
        
        let nextStartIndex = buffer.startIndex.advanced(by: ByteLength.type + ByteLength.payloadLength + messageLength + ByteLength.checksum)
        if nextStartIndex == buffer.endIndex {
            buffer.removeAll(keepingCapacity: true)
            bufferState = .empty
        } else {
            let next = Data(buffer[nextStartIndex...])
            buffer.removeAll(keepingCapacity: true)
            bufferState = .empty
            appendTypeUndeterminedDataAndContinue(next)
        }
    }
    
    private func continueWithFile(state: ReceiveFileState) {
        /*
         |    Header    |Content|Checksum|
         |Type|Length|ID|  Data |Checksum|
         |  Payload |
         */
        switch state {
        case .header:
            guard buffer.count > ByteLength.type + ByteLength.payloadLength + ByteLength.fileMessageID else {
                return
            }
            let payloadLength = {
                let startIndex = buffer.startIndex.advanced(by: ByteLength.type)
                let endIndex = buffer.startIndex.advanced(by: ByteLength.type + ByteLength.payloadLength)
                let data = buffer[startIndex..<endIndex]
                return Int(Int32(data: data, endianess: .big))
            }()
            let idData = {
                // Must contains the `id` since count is checked at the beginning of this func
                let startIndex = buffer.startIndex.advanced(by: ByteLength.type + ByteLength.payloadLength)
                let endIndex = buffer.index(startIndex, offsetBy: ByteLength.fileMessageID)
                return buffer[startIndex..<endIndex]
            }()
            let fileMessageId = UUID(data: idData).uuidString.lowercased()
            let contentLength = payloadLength - ByteLength.fileMessageID
            
            let headerStartIndex = buffer.startIndex
            let headerEndIndex = buffer.startIndex.advanced(by: ByteLength.type + ByteLength.payloadLength + ByteLength.fileMessageID)
            buffer.removeSubrange(headerStartIndex..<headerEndIndex)
            
            let fileHandle: FileHandle?
            let fileURL: URL?
            let copyToURL: URL?
            if let message = MessageDAO.shared.getMessage(messageId: fileMessageId), let mediaURL = message.mediaUrl {
                let category = AttachmentContainer.Category(messageCategory: message.category) ?? .files
                fileURL = AttachmentContainer.url(for: category, filename: mediaURL)
                if let transcriptMessage = TranscriptMessageDAO.shared.transcriptMessage(messageId: fileMessageId), let mediaURL = transcriptMessage.mediaUrl {
                    copyToURL = AttachmentContainer.url(transcriptId: transcriptMessage.transcriptId, filename: mediaURL)
                } else {
                    copyToURL = nil
                }
            } else if let transcriptMessage = TranscriptMessageDAO.shared.transcriptMessage(messageId: fileMessageId), let mediaURL = transcriptMessage.mediaUrl {
                fileURL = AttachmentContainer.url(transcriptId: fileMessageId, filename: mediaURL)
                copyToURL = nil
            } else {
                fileURL = nil
                copyToURL = nil
            }
            if let fileURL {
                do {
                    Logger.general.debug(category: "DeviceTransferDataParser", message: "File opened: \(fileURL)")
                    let fileManager = FileManager.default
                    if fileManager.fileExists(atPath: fileURL.path) {
                        try? fileManager.removeItem(at: fileURL)
                    }
                    fileManager.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
                    fileHandle = try FileHandle(forWritingTo: fileURL)
                } catch {
                    Logger.general.debug(category: "DeviceTransferDataParser", message: "Init FileHandle failed: \(error)")
                    fileHandle = nil
                }
            } else {
                fileHandle = nil
                Logger.general.debug(category: "DeviceTransferDataParser", message: "Message not exists: \(fileMessageId)")
            }
            var checksum = CRC32()
            checksum.update(data: idData)
            let state: ReceiveFileState = .content(handle: fileHandle,
                                                   fileURL: fileURL,
                                                   copyToURL: copyToURL,
                                                   remainingLength: contentLength,
                                                   checksum: checksum)
            // No one reads it. calling to `continueWithFile(state:)` blocks current
            // thread with argument of `state`, due to the thread blocking no new data
            // is coming in until current buffer is well handled. But set it anyway,
            // that would keeps `buffer` and `bufferState` always in sync
            bufferState = .receivingFile(state)
            continueWithFile(state: state)
        case let .content(handle, fileURL, copyToURL, remainingLength, checksum):
            var newChecksum = checksum
            if buffer.count <= remainingLength {
                handle?.write(buffer)
                newChecksum.update(data: buffer)
                let state: ReceiveFileState
                if buffer.count == remainingLength {
                    let localChecksum = newChecksum.finalize()
                    state = .checksum(fileURL: fileURL,
                                      copyToURL: copyToURL,
                                      localChecksum: localChecksum,
                                      remoteChecksumDataSlice: Data())
                } else {
                    state = .content(handle: handle,
                                     fileURL: fileURL,
                                     copyToURL: copyToURL,
                                     remainingLength: remainingLength - buffer.count,
                                     checksum: newChecksum)
                }
                buffer.removeAll(keepingCapacity: true)
                bufferState = .receivingFile(state)
            } else {
                // By the if statement, all file content is retrieved,
                // and at least 1 byte of checksum is in `buffer`
                let fileEndIndex = buffer.startIndex.advanced(by: remainingLength)
                let fileContent = buffer[..<fileEndIndex]
                handle?.write(fileContent)
                try? handle?.close()
                Logger.general.debug(category: "DeviceTransferDataParser", message: "File closed")
                newChecksum.update(data: fileContent)
                let localChecksum = newChecksum.finalize()
                buffer.removeSubrange(..<fileEndIndex)
                
                let remoteChecksumSlice = buffer.prefix(ByteLength.checksum)
                let state: ReceiveFileState = .checksum(fileURL: fileURL,
                                                        copyToURL: copyToURL,
                                                        localChecksum: localChecksum,
                                                        remoteChecksumDataSlice: remoteChecksumSlice)
                buffer.removeSubrange(..<buffer.startIndex.advanced(by: remoteChecksumSlice.count))
                // Like above, no one reads it but keeps `buffer` and `bufferState` always in sync
                bufferState = .receivingFile(state)
                continueWithFile(state: state)
            }
        case let .checksum(fileURL, copyToURL, localChecksum, remoteChecksumDataSlice):
            let remainingChecksumCount = ByteLength.checksum - remoteChecksumDataSlice.count
            if buffer.count < remainingChecksumCount {
                let state: ReceiveFileState = .checksum(fileURL: fileURL,
                                                        copyToURL: copyToURL,
                                                        localChecksum: localChecksum,
                                                        remoteChecksumDataSlice: remoteChecksumDataSlice + buffer)
                self.bufferState = .receivingFile(state)
            } else {
                let remoteChecksumData = remoteChecksumDataSlice + buffer.prefix(remainingChecksumCount)
                let remoteChecksum = UInt64(data: remoteChecksumData, endianess: .big)
                if localChecksum == remoteChecksum {
                    Logger.general.debug(category: "DeviceTransferDataParser", message: "File checksum passed\n")
                    let dataAfterChecksum: Data?
                    if buffer.count > remainingChecksumCount {
                        let dataAfterChecksumIndex = buffer.startIndex.advanced(by: remainingChecksumCount)
                        dataAfterChecksum = Data(buffer[dataAfterChecksumIndex...])
                    } else {
                        dataAfterChecksum = nil
                    }
                    buffer.removeAll(keepingCapacity: true)
                    bufferState = .empty
                    if let dataAfterChecksum {
                        appendTypeUndeterminedDataAndContinue(dataAfterChecksum)
                    }
                    if let fileURL {
                        if let copyToURL {
                            try? FileManager.default.copyItem(at: fileURL, to: copyToURL)
                        }
                        delegate?.deviceTransferDataParser(self, didParseFile: fileURL)
                    }
                } else {
                    if let fileURL {
                        try? FileManager.default.removeItem(at: fileURL)
                    }
                    bufferState = .failed
                    delegate?.deviceTransferDataParser(self, didParseFailed: .mismatchedChecksum)
                }
            }
        }
    }
    
}
