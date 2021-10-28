import XCTest
@testable import MixinServices

class CryptoTests: XCTestCase {
    
    func testAESCryptorWithoutPadding() throws {
        let key = Ed25519PrivateKey().rfc8032Representation
        let iv = Data(withNumberOfSecuredRandomBytes: 16)!
        
        let plain1 = "0123456789ABCDEF".data(using: .utf8)!
        let encrypted1 = try AESCryptor.encrypt(plain1, with: key, iv: iv, padding: .none)
        let decrypted1 = try AESCryptor.decrypt(encrypted1, with: key, iv: iv)
        XCTAssertEqual(plain1, decrypted1)
        
        // No padding requires input to be aligned
        XCTAssertThrowsError(try AESCryptor.encrypt(Data([0x01]), with: key, iv: iv, padding: .none))
    }
    
    func testAESCryptorWithPKCS7Padding() throws {
        let plain = "L".data(using: .utf8)!
        let key = Ed25519PrivateKey().rfc8032Representation
        let iv = Data(withNumberOfSecuredRandomBytes: 16)!
        let encrypted = try AESCryptor.encrypt(plain, with: key, iv: iv, padding: .pkcs7)
        let decrypted = try AESCryptor.decrypt(encrypted, with: key, iv: iv)
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
