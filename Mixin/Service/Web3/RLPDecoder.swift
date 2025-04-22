import Foundation
import BigInt
import web3

struct RLPDecoder {
    
    enum RLPValue {
        case empty
        case data(Data)
        case list([RLPValue])
        case int(Int)
        case bint(BigInt)
        case buint(BigUInt)
        case address(EthereumAddress)
    }
    
    enum DecodingError: Error {
        case invalidInput
        case invalidLength
        case invalidType
        case unsupportedType
        case addressLengthMismatch
    }
    
    static func decode(_ input: Data) throws -> RLPValue {
        guard !input.isEmpty else {
            return .empty
        }
        
        let firstByte = input[input.startIndex]
        
        if firstByte <= 0x7f {
            // Single byte
            return .data(input.subdata(in: input.startIndex..<input.startIndex.advanced(by: 1)))
        } else if firstByte <= 0xb7 {
            // Short string (0-55 bytes)
            let length = Int(firstByte) - 0x80
            guard input.count >= 1 + length else {
                throw DecodingError.invalidLength
            }
            return .data(input.subdata(in: input.startIndex.advanced(by: 1)..<input.startIndex.advanced(by: 1 + length)))
        } else if firstByte <= 0xbf {
            // Long string (>55 bytes)
            let lengthOfLength = Int(firstByte) - 0xb7
            guard input.count >= 1 + lengthOfLength else {
                throw DecodingError.invalidLength
            }
            let lengthData = input.subdata(in: input.startIndex.advanced(by: 1)..<input.startIndex.advanced(by: 1 + lengthOfLength))
            let length = try decodeLength(lengthData)
            guard input.count >= 1 + lengthOfLength + length else {
                throw DecodingError.invalidLength
            }
            return .data(input.subdata(in: input.startIndex.advanced(by: 1 + lengthOfLength)..<input.startIndex.advanced(by: 1 + lengthOfLength + length)))
        } else if firstByte <= 0xf7 {
            // Short list (0-55 items)
            let length = Int(firstByte) - 0xc0
            guard input.count >= 1 + length else {
                throw DecodingError.invalidLength
            }
            return try decodeList(input.subdata(in: input.startIndex.advanced(by: 1)..<input.startIndex.advanced(by: 1 + length)))
        } else {
            // Long list (>55 items)
            let lengthOfLength = Int(firstByte) - 0xf7
            guard input.count >= 1 + lengthOfLength else {
                throw DecodingError.invalidLength
            }
            let lengthData = input.subdata(in: input.startIndex.advanced(by: 1)..<input.startIndex.advanced(by: 1 + lengthOfLength))
            let length = try decodeLength(lengthData)
            guard input.count >= 1 + lengthOfLength + length else {
                throw DecodingError.invalidLength
            }
            return try decodeList(input.subdata(in: input.startIndex.advanced(by: 1 + lengthOfLength)..<input.startIndex.advanced(by: 1 + lengthOfLength + length)))
        }
    }
    
    private static func decodeLength(_ data: Data) throws -> Int {
        guard !data.isEmpty else {
            return 0
        }
        
        if data.count == 1 {
            return Int(data[data.startIndex])
        }
        
        var result = 0
        for byte in data {
            result = result << 8 + Int(byte)
        }
        return result
    }
    
    private static func decodeList(_ data: Data) throws -> RLPValue {
        var elements: [RLPValue] = []
        var remainingData = data
        
        while !remainingData.isEmpty {
            let (element, consumed) = try decodeNext(remainingData)
            elements.append(element)
            remainingData = remainingData.subdata(in: consumed..<remainingData.endIndex)
        }
        
        return .list(elements)
    }
    
    private static func decodeNext(_ data: Data) throws -> (RLPValue, Int) {
        let decoded = try decode(data)
        let encoded = try encode(decoded)
        return (decoded, encoded.count)
    }
    
    private static func encode(_ value: RLPValue) throws -> Data {
        switch value {
        case .empty:
            return Data()
            
        case .data(let data):
            if data.count == 1 && data[data.startIndex] <= 0x7f {
                return data
            } else if data.count <= 55 {
                var result = Data()
                result.append(UInt8(0x80 + data.count))
                result.append(data)
                return result
            } else {
                let lengthData = encodeLength(data.count)
                var result = Data()
                result.append(UInt8(0xb7 + lengthData.count))
                result.append(lengthData)
                result.append(data)
                return result
            }
            
        case .list(let array):
            var encodedData = Data()
            for element in array {
                encodedData.append(try encode(element))
            }
            
            if encodedData.count <= 55 {
                var result = Data()
                result.append(UInt8(0xc0 + encodedData.count))
                result.append(encodedData)
                return result
            } else {
                let lengthData = encodeLength(encodedData.count)
                var result = Data()
                result.append(UInt8(0xf7 + lengthData.count))
                result.append(lengthData)
                result.append(encodedData)
                return result
            }
            
        default:
            throw DecodingError.unsupportedType
        }
    }
    
    private static func encodeLength(_ length: Int) -> Data {
        var length = length
        var data = Data()
        while length > 0 {
            data.insert(UInt8(length & 0xff), at: 0)
            length = length >> 8
        }
        return data
    }
    
}

extension RLPDecoder.RLPValue {
    
    func asInt() throws -> Int {
        guard case .data(let data) = self else {
            throw RLPDecoder.DecodingError.invalidType
        }
        
        var result = 0
        for byte in data {
            result = result << 8 + Int(byte)
        }
        return result
    }
    
    func asBigInt() throws -> BigInt {
        guard case .data(let data) = self else {
            throw RLPDecoder.DecodingError.invalidType
        }
        return BigInt(data)
    }
    
    func asBigUInt() throws -> BigUInt {
        guard case .data(let data) = self else {
            throw RLPDecoder.DecodingError.invalidType
        }
        return BigUInt(data)
    }
    
    func asData() throws -> Data {
        guard case .data(let data) = self else {
            throw RLPDecoder.DecodingError.invalidType
        }
        return data
    }
    
    func asAddress() throws -> EthereumAddress {
        guard case .data(let data) = self else {
            throw RLPDecoder.DecodingError.invalidType
        }
        guard data.count == 20 else {
            throw RLPDecoder.DecodingError.addressLengthMismatch
        }
        return EthereumAddress(data.hexEncodedString())
    }
    
    func asArray() throws -> [Self] {
        guard case .list(let array) = self else {
            throw RLPDecoder.DecodingError.invalidType
        }
        return array
    }
    
    func map<T>(_ transform: (Self) throws -> T) throws -> [T] {
        guard case .list(let array) = self else {
            throw RLPDecoder.DecodingError.invalidType
        }
        return try array.map(transform)
    }
    
}
