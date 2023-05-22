import Foundation
import Network
import MixinServices

final class DeviceTransferProtocol: NWProtocolFramerImplementation {
    
    enum MessageKey {
        static let header = "h"
        static let fileContext = "f"
    }
    
    struct FileContext {
        
        static let mtu = 0xffff
        
        let header: DeviceTransferHeader
        let id: UUID
        let remainingLength: Int
        
        func replacingRemainingLength(with length: Int) -> FileContext {
            FileContext(header: header, id: id, remainingLength: length)
        }
        
    }
    
    private enum ReceivingState {
        case pendingCommandOrMessageContent(DeviceTransferHeader)
        case pendingFileID(DeviceTransferHeader)
        case pendingFileContent(FileContext)
    }
    
    static let label = "DeviceTransfer"
    static let definition = NWProtocolFramer.Definition(implementation: DeviceTransferProtocol.self)
    static let maxMessageDataSize = 500 * bytesPerKiloByte
    static let checksumLength = 8
    
    private var receivingState: ReceivingState?
    
    required init(framer: NWProtocolFramer.Instance) {
        
    }
    
    func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult {
        .ready
    }
    
    func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        while true {
            let message = NWProtocolFramer.Message(definition: DeviceTransferProtocol.definition)
            switch receivingState {
            case .none:
                let header: ParseResult<DeviceTransferHeader> = parseContent(framer: framer)
                switch header {
                case .notEnough(let size):
                    return size
                case .enough(let header):
                    switch header.type {
                    case .command, .message:
                        receivingState = .pendingCommandOrMessageContent(header)
                    case .file:
                        receivingState = .pendingFileID(header)
                    }
                }
            case let .pendingCommandOrMessageContent(header):
                message[MessageKey.header] = header
                let length = Int(header.length) + Self.checksumLength
                receivingState = nil
                if !framer.deliverInputNoCopy(length: length, message: message, isComplete: true) {
                    return 0
                }
            case let .pendingFileID(header):
                let id: ParseResult<UUID> = parseContent(framer: framer)
                switch id {
                case .notEnough(let size):
                    return size
                case .enough(let id):
                    let contentLength = Int(header.length) - UUID.bufferCount + Self.checksumLength
                    let context = FileContext(header: header, id: id, remainingLength: contentLength)
                    receivingState = .pendingFileContent(context)
                }
            case let .pendingFileContent(context):
                let deliveringLength = min(FileContext.mtu, context.remainingLength)
                let newRemainingLength = context.remainingLength - deliveringLength
                let newContext = context.replacingRemainingLength(with: newRemainingLength)
                if newRemainingLength == 0 {
                    receivingState = nil
                } else {
                    receivingState = .pendingFileContent(newContext)
                }
                message[MessageKey.fileContext] = newContext
                if !framer.deliverInputNoCopy(length: deliveringLength, message: message, isComplete: true) {
                    return 0
                }
            }
        }
    }
    
    func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool) {
        do {
            try framer.writeOutputNoCopy(length: messageLength)
        } catch {
            Logger.general.error(category: "DeviceTransferProtocol", message: "Failed to output: \(error)")
        }
    }
    
    func wakeup(framer: NWProtocolFramer.Instance) {
        
    }
    
    func stop(framer: NWProtocolFramer.Instance) -> Bool {
        true
    }
    
    func cleanup(framer: NWProtocolFramer.Instance) {
        
    }
    
}

extension DeviceTransferProtocol {
    
    // Although Network.framework provides a frame generation mechanism for sending
    // messages, this mechanism relies on obtaining metadata in a Key-Value pattern,
    // which may result in potential performance impact. Therefore, we utilize
    // custom functions to combine the header and checksum, and directly send the
    // message in binary, aiming to achieve optimal performance.
    
    static func output(command: DeviceTransferCommand) -> Data? {
        do {
            let jsonData = try JSONEncoder.default.encode(command)
            return package(type: .command, data: jsonData)
        } catch {
            Logger.general.error(category: "DeviceTransferProtocol", message: "Failed to encode command: \(error)")
            return nil
        }
    }
    
    static func output<Record: DeviceTransferRecord>(type: DeviceTransferRecordType, data: Record) -> Data? {
        do {
            let typedRecord = DeviceTransferTypedRecord(type: type, data: data)
            let jsonData = try JSONEncoder.default.encode(typedRecord)
            if jsonData.count >= maxMessageDataSize {
                Logger.general.warn(category: "DeviceTransferProtocol", message: "Data size is too large: \(data)")
                return nil
            } else {
                return package(type: .message, data: jsonData)
            }
        } catch {
            Logger.general.error(category: "DeviceTransferProtocol", message: "Failed to encode record: \(error)")
            return nil
        }
    }
    
    private static func package(type: DeviceTransferHeader.ContentType, data: Data) -> Data {
        let header = DeviceTransferHeader(type: type, length: Int32(data.count))
        let checksum = CRC32.checksum(data: data)
        let checksumData = checksum.data(endianness: .big)
        return header.encoded() + data + checksumData
    }
    
}

extension DeviceTransferProtocol {
    
    private enum ParseResult<Success> {
        case enough(Success)
        case notEnough(Int)
    }
    
    private func parseContent<Content: RawBufferInitializable>(framer: NWProtocolFramer.Instance) -> ParseResult<Content> {
        let contentSize = Content.bufferCount
        var content: Content?
        let parsed = framer.parseInput(minimumIncompleteLength: contentSize, maximumLength: contentSize) { buffer, isComplete in
            guard let buffer, buffer.count == contentSize else {
                return 0
            }
            guard let currentContent = Content(buffer) else {
                framer.markFailed(error: .posix(.EBADMSG))
                return 0
            }
            content = currentContent
            return contentSize
        }
        if parsed, let content {
            return .enough(content)
        } else {
            return .notEnough(contentSize)
        }
    }
    
}
