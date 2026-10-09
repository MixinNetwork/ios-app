import Foundation

public struct BlazeMessageFramer {
    
    public enum FramingError: Error, Sendable, Equatable, LocalizedError {
        
        case encodingFailed
        case compressionFailed
        case payloadTooLarge(size: Int)
        case decompressionFailed
        case decodingFailed
        
        public var errorDescription: String? {
            switch self {
            case .encodingFailed:
                "Encoding failed"
            case .compressionFailed:
                "Compression failed"
            case let .payloadTooLarge(size):
                "Payload too large: \(size) bytes"
            case .decompressionFailed:
                "Decompression failed"
            case .decodingFailed:
                "Decoding failed"
            }
        }
        
    }
    
    public static let maxPayloadSize: Int = Int(2 * bytesPerMegaByte)
    
    static func encodeAndCompress(message: BlazeMessage) throws(FramingError) -> Data {
        let jsonData: Data
        do {
            jsonData = try JSONEncoder.default.encode(message)
        } catch {
            throw .encodingFailed
        }
        
        let gzippedData: Data
        do {
            gzippedData = try jsonData.gzipped()
        } catch {
            reporter.report(error: MixinServicesError.gzipFailed)
            throw .compressionFailed
        }
        
        guard gzippedData.count < maxPayloadSize else {
            let conversationID = message.params?.conversationId ?? ""
            let category = message.params?.category ?? ""
            reporter.report(
                error: MixinServicesError.messageTooBig(
                    gzipSize: gzippedData.count,
                    category: category,
                    conversationId: conversationID,
                )
            )
            if conversationID.isEmpty {
                Logger.general.error(
                    category: "BlazeMessageFramer",
                    message: "Message too big, size:\(gzippedData.count / 1024)k",
                )
            } else {
                Logger.conversation(id: conversationID).info(
                    category: "BlazeMessageFramer",
                    message: "Message too big, size:\(gzippedData.count / 1024)k",
                )
            }
            throw .payloadTooLarge(size: gzippedData.count)
        }
        
        return gzippedData
    }
    
    static func decompressAndDecode(data: Data) throws(FramingError) -> BlazeMessage {
        guard data.isGzipped else {
            throw .decompressionFailed
        }
        let unzipped: Data
        do {
            unzipped = try data.gunzipped()
        } catch {
            throw .decompressionFailed
        }
        do {
            return try JSONDecoder.default.decode(BlazeMessage.self, from: unzipped)
        } catch {
            throw .decodingFailed
        }
    }
    
}
