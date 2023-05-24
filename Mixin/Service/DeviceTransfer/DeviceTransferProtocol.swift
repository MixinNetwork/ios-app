import Foundation
import Network
import libsignal_protocol_c
import MixinServices

final class DeviceTransferProtocol: NWProtocolFramerImplementation {
    
    enum MessageKey {
        static let header = "h"
        static let fileContext = "f"
    }
    
    struct FileHeader: RawBufferInitializable {
        
        static let bufferCount = 32
        
        let id: UUID
        let iv: Data
        
        init?(_ buffer: UnsafeMutableRawBufferPointer) {
            assert(buffer.count == Self.bufferCount)
            guard let ivAddress = buffer.baseAddress?.advanced(by: 16) else {
                return nil
            }
            
            // https://forums.swift.org/t/guarantee-in-memory-tuple-layout-or-dont/40122
            // Tuples have always had their own guarantee: if all the elements are the same type,
            // they will be laid out in order by stride (size rounded up to alignment), just like
            // a fixed-sized array in C.
            let uuid = buffer.load(as: uuid_t.self)
            
            self.id = UUID(uuid: uuid)
            self.iv = Data(bytes: ivAddress, count: 16)
        }
        
    }
    
    struct FileContext {
        
        static let mtu = 0xffff
        
        let header: DeviceTransferHeader
        let fileHeader: FileHeader
        let remainingLength: Int
        
        func replacingRemainingLength(with length: Int) -> FileContext {
            FileContext(header: header,
                        fileHeader: fileHeader,
                        remainingLength: length)
        }
        
    }
    
    private enum ReceivingState {
        case pendingCommandOrMessageContent(DeviceTransferHeader)
        case pendingFileHeader(DeviceTransferHeader)
        case pendingFileContent(FileContext)
    }
    
    static let label = "DeviceTransfer"
    static let definition = NWProtocolFramer.Definition(implementation: DeviceTransferProtocol.self)
    static let maxRecordDataSize = 500 * bytesPerKiloByte
    static let ivDataCount = 16
    static let hmacDataCount = HMACSHA256.digestDataCount
    
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
                let result: ParseResult<DeviceTransferHeader> = parseContent(framer: framer)
                switch result {
                case .notEnough(let size):
                    return size
                case .enough(let header):
                    switch header.type {
                    case .command, .message:
                        receivingState = .pendingCommandOrMessageContent(header)
                    case .file:
                        receivingState = .pendingFileHeader(header)
                    }
                }
            case let .pendingCommandOrMessageContent(header):
                message[MessageKey.header] = header
                let length = Int(header.length) + Self.hmacDataCount
                receivingState = nil
                if !framer.deliverInputNoCopy(length: length, message: message, isComplete: true) {
                    return 0
                }
            case let .pendingFileHeader(header):
                let result: ParseResult<FileHeader> = parseContent(framer: framer)
                switch result {
                case .notEnough(let size):
                    return size
                case .enough(let fileHeader):
                    let contentLength = Int(header.length) - FileHeader.bufferCount + Self.hmacDataCount
                    let context = FileContext(header: header, fileHeader: fileHeader, remainingLength: contentLength)
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
            // No magic here. See code below for output framing
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
    
    enum OutputError: Error {
        case maxSizeExceeded
    }
    
    static func output(command: DeviceTransferCommand, key: Key) throws -> Data {
        let data = try JSONEncoder.default.encode(command)
        return try package(type: .command, data: data, key: key)
    }
    
    static func output<Record: DeviceTransferRecord>(type: DeviceTransferRecordType, data: Record, key: Key) throws -> Data {
        let typedRecord = DeviceTransferTypedRecord(type: type, data: data)
        let data = try JSONEncoder.default.encode(typedRecord)
        if data.count >= maxRecordDataSize {
            throw OutputError.maxSizeExceeded
        } else {
            return try package(type: .message, data: data, key: key)
        }
    }
    
    private static func package(type: DeviceTransferHeader.ContentType, data: Data, key: Key) throws -> Data {
        let encrypted = try AESCryptor.encrypt(data, with: key.aes)
        let hmac = HMACSHA256.mac(for: encrypted, using: key.hmac)
        let header = DeviceTransferHeader(type: type, length: Int32(encrypted.count))
        return header.encoded() + encrypted + hmac
    }
    
}

extension DeviceTransferProtocol {
    
    struct Key {
        
        let raw: Data
        
        var aes: Data {
            raw[..<firstHMACIndex]
        }
        
        var hmac: Data {
            raw[firstHMACIndex...]
        }
        
        private let firstHMACIndex: Data.Index
        
        init() {
            let seed = Data(withNumberOfSecuredRandomBytes: 32)!
            self.init(seed: seed)
        }
        
        init(raw: Data) {
            self.raw = raw
            self.firstHMACIndex = raw.startIndex.advanced(by: 32)
        }
        
        private init(seed: Data) {
            assert(seed.count == 32)
            var derived: UnsafeMutablePointer<UInt8>!
            var hkdf: OpaquePointer!
            
            let status = hkdf_create(&hkdf, 3, globalSignalContext)
            assert(status == 0)
            let salt = Data(repeating: 0, count: 32)
            let info = "Mixin Device Transfer".data(using: .utf8)!
            let derivedCount = salt.withUnsafeBytes { salt in
                info.withUnsafeBytes { info in
                    seed.withUnsafeBytes { seed in
                        hkdf_derive_secrets(hkdf,
                                            &derived,
                                            seed.baseAddress,
                                            seed.count,
                                            salt.baseAddress,
                                            salt.count,
                                            info.baseAddress,
                                            info.count,
                                            64)
                    }
                }
            }
            assert(derivedCount == 64)
            
            let raw = Data(bytesNoCopy: derived, count: 64, deallocator: .free)
            self.init(raw: raw)
        }
        
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
