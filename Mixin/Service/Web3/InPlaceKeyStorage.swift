import Foundation
import web3

final class InPlaceKeyStorage: EthereumSingleKeyStorageProtocol {
    
    enum Error: Swift.Error {
        case unable
    }
    
    private let raw: Data
    
    init(raw: Data) {
        self.raw = raw
    }
    
    func storePrivateKey(key: Data) throws {
        throw Error.unable
    }
    
    func loadPrivateKey() throws -> Data {
        raw
    }
    
}
