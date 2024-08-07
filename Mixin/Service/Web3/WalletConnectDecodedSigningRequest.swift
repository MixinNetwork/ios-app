import Foundation
import web3
import WalletConnectSign

struct WalletConnectDecodedSigningRequest {
    
    enum Error: Swift.Error {
        case invalidParameters
        case hexDecoding
        case utf8Encoding
        case chainNotSupported
    }
    
    enum Signable {
        case raw(Data)
        case typed(TypedData)
    }
    
    let raw: WalletConnectSign.Request
    let chain: Web3Chain
    let address: String
    let signable: Signable
    let humanReadable: String
    
    static func ethPersonalSign(request: WalletConnectSign.Request) throws -> WalletConnectDecodedSigningRequest {
        guard let chain = Web3Chain.chain(caip2: request.chainId) else {
            throw Error.chainNotSupported
        }
        let params = try request.params.get([String].self)
        guard params.count >= 2 else {
            // Some dapps send malformed `params` with 3 or more items
            // e.g. 1inch sends 3 params with an empty string as last one
            throw Error.invalidParameters
        }
        let address = params[1]
        let encodedMessage = params[0]
        guard let decodedMessage = Data(hex: encodedMessage) else {
            throw Error.hexDecoding
        }
        let humanReadable = String(data: decodedMessage, encoding: .utf8) ?? encodedMessage
        return WalletConnectDecodedSigningRequest(raw: request,
                                                  chain: chain,
                                                  address: address,
                                                  signable: .raw(decodedMessage),
                                                  humanReadable: humanReadable)
    }
    
    static func ethSignTypedData(request: WalletConnectSign.Request) throws -> WalletConnectDecodedSigningRequest {
        guard let chain = Web3Chain.chain(caip2: request.chainId) else {
            throw Error.chainNotSupported
        }
        let params = try request.params.get([String].self)
        guard params.count >= 2 else {
            // Some dapps send malformed `params` with 3 or more items
            // e.g. 1inch sends 3 params with an empty string as last one
            throw Error.invalidParameters
        }
        let address = params[0]
        let messageString = params[1]
        guard let messageData = messageString.data(using: .utf8) else {
            throw Error.utf8Encoding
        }
        let typedData = try JSONDecoder.default.decode(TypedData.self, from: messageData)
        let humanReadable = typedData.description
        return WalletConnectDecodedSigningRequest(raw: request,
                                                  chain: chain,
                                                  address: address,
                                                  signable: .typed(typedData),
                                                  humanReadable: humanReadable)
    }
    
    static func solanaSignMessage(request: WalletConnectSign.Request) throws -> WalletConnectDecodedSigningRequest {
        guard let chain = Web3Chain.chain(caip2: request.chainId) else {
            throw Error.chainNotSupported
        }
        let params = try request.params.get([String: String].self)
        guard
            params.count == 2,
            let message = params["message"],
            let pubkey = params["pubkey"]
        else {
            throw Error.invalidParameters
        }
        guard let messageData = Data(base58EncodedString: message) else {
            throw Error.utf8Encoding
        }
        return WalletConnectDecodedSigningRequest(raw: request,
                                                  chain: chain,
                                                  address: pubkey,
                                                  signable: .raw(messageData),
                                                  humanReadable: message)
    }
    
}
