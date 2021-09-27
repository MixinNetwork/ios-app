import XCTest
@testable import MixinServices

class ServicesTests: XCTestCase {
    
    func testMessageCryptor() throws {
        let plain = "L".data(using: .utf8)!
        let localKey = Ed25519PrivateKey()
        let remoteKey = Ed25519PrivateKey()
        let remoteSessionID = UUID()
        
        let encrypted = try EncryptedProtocol.encrypt(plain,
                                                      with: localKey,
                                                      remotePublicKey: remoteKey.publicKey.x25519Representation,
                                                      remoteSessionID: remoteSessionID)
        let decrypted = try EncryptedProtocol.decrypt(cipher: encrypted, with: remoteKey)
        XCTAssertEqual(plain, decrypted)
    }
    
}
