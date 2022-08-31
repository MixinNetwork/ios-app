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
    
    func testSHA3_256() {
        let raw = Data(hexEncodedString: "3039326262663461613432633963643336376239663465383363353861393031363539353037316465636261386436646330633437643565613862326363633535485841484668386b6859424757413256336f5555765841583461576e517345794e7a4b6f41334c6e4a6b78744b514e686357536834537774373261316277376147387554673946333179627a534a79754e48454e554274476f62556648624b4e505559596b486e6875507457737a6143754e4a336e42785a34437274385138416d4a32665a7a6e4c783345444d32457166363364724e6d573656566d6d7a42515563344e324a61587a46747434484646577476556b")!
        let hash = SHA3_256.hash(data: raw)!.hexEncodedString()
        XCTAssertEqual(hash, "25c945f52d5742aa6c3d26edaab75113cb59e824e7ff5a42f71da86800c7ce14")
    }
    
}
