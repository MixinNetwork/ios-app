import Foundation
import web3

struct WalletConnectMessage<Signable> {
    
    enum Error: Swift.Error {
        case hexDecoding
        case utf8Encoding
    }
    
    let signable: Signable
    let humanReadable: String
    
}

extension WalletConnectMessage where Signable == Any {
    
    static func personalSign(string: String) throws -> WalletConnectMessage<Data> {
        guard let decoded = Data(hex: string) else {
            throw Error.hexDecoding
        }
        let humanReadable = String(data: decoded, encoding: .utf8) ?? string
        return WalletConnectMessage<Data>(signable: decoded, humanReadable: humanReadable)
    }
    
    static func typedData(string: String) throws -> WalletConnectMessage<TypedData> {
        guard let message = string.data(using: .utf8) else {
            throw Error.utf8Encoding
        }
        let typedData = try JSONDecoder.default.decode(TypedData.self, from: message)
        return WalletConnectMessage<TypedData>(signable: typedData, humanReadable: typedData.description)
    }
    
}
