import XCTest
@testable import MixinServices
@testable import Tip

class ServicesTests: XCTestCase {
    
    func testMessageCryptor() throws {
        let plain = "L".data(using: .utf8)!
        let localKey = Ed25519PrivateKey()
        let remoteKey = Ed25519PrivateKey()
        let remoteSessionID = UUID()
        
        let encrypted = try EncryptedProtocol.encrypt(plain,
                                                      with: localKey,
                                                      remotePublicKey: remoteKey.publicKey.x25519Representation,
                                                      remoteSessionID: remoteSessionID,
                                                      extensionSession: nil)
        let decrypted = try EncryptedProtocol.decrypt(cipher: encrypted,
                                                      with: remoteKey,
                                                      sessionId: remoteSessionID)
        XCTAssertEqual(plain, decrypted)
    }
    
    func testTIPNodeSign() throws {
        let key = Data(hexEncodedString: "1435213952d52e8298938a5aea46725009ada04b894359aa3454d886298a811b")!
        let ephemeral = "092bbf4aa42c9cd367b9f4e83c58a9016595071decba8d6dc0c47d5ea8b2ccc5".data(using: .utf8)!
        let watcher = Data(hexEncodedString: "ffff34d612e97a7eea2c766c2b0972a444fdf9271091e48e9b4938381f8b2e7d")!
        let nonce: UInt64 = 2
        let grace: UInt64 = 11059200000000000
        let signer = TIPConfig.current.signers[0]
        
        XCTAssertEqual(signer.identity, "5HXAHFh8khYBGWA2V3oUUvXAX4aWnQsEyNzKoA3LnJkxtKQNhcWSh4Swt72a1bw7aG8uTg9F31ybzSJyuNHENUBtGobUfHbKNPUYYkHnhuPtWszaCuNJ3nBxZ4Crt8Q8AmJ2fZznLx3EDM2Eqf63drNmW6VVmmzBQUc4N2JaXzFtt4HFFWtvUk")
        
        guard let suite = CryptoNewSuiteBn256() else {
            fatalError()
        }
        guard let userSk = suite.scalar() else {
            fatalError()
        }
        userSk.setBytes(key)
        
        let request = try TIPSignRequest(userSk: userSk,
                                         signer: signer,
                                         ephemeral: ephemeral,
                                         watcher: watcher,
                                         nonce: nonce,
                                         grace: grace,
                                         assignee: nil)
    }
    
    func testAmountFormatter() {
        XCTAssertEqual(AmountFormatter.formattedAmount("100.000"),      "100")
        XCTAssertEqual(AmountFormatter.formattedAmount("100.00100"),    "100.001")
        XCTAssertEqual(AmountFormatter.formattedAmount("1.1E-4"),       "0.00011")
        XCTAssertEqual(AmountFormatter.formattedAmount("-1.100E-5"),    "-0.000011")
        XCTAssertEqual(AmountFormatter.formattedAmount("01.010"),       "1.01")
        XCTAssertEqual(AmountFormatter.formattedAmount("0"),            "0")
        XCTAssertEqual(AmountFormatter.formattedAmount("0.00000001"),   "0.00000001")
        XCTAssertEqual(AmountFormatter.formattedAmount("0.00000009"),   "0.00000009")
    }
    
}
