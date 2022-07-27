import XCTest
@testable import MixinServices

class CryptoTests: XCTestCase {
    
    func testAESCryptorWithPKCS7Padding() throws {
        let plain = "L".data(using: .utf8)!
        let key = Ed25519PrivateKey().rfc8032Representation
        let encrypted = try AESCryptor.encrypt(plain, with: key)
        let decrypted = try AESCryptor.decrypt(encrypted, with: key)
        XCTAssertEqual(plain, decrypted)
    }
    
    func testAESGCMCryptor() throws {
        let plain = "L".data(using: .utf8)!
        let key = Ed25519PrivateKey().rfc8032Representation
        let iv = Data(withNumberOfSecuredRandomBytes: 16)!
        let encrypted = try AESGCMCryptor.encrypt(plain, with: key, iv: iv)
        let decrypted = try AESGCMCryptor.decrypt(encrypted, with: key, iv: iv)
        XCTAssertEqual(plain, decrypted)
    }
    
}
