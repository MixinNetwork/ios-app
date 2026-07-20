import Foundation

public struct ExportSaltRequest {
    
    public let userID: String
    public let pin: String
    public let mnemonics: MixinMnemonics
    public let publicKey: String
    public let signature: String
    
    public init(userID: String, pin: String) async throws {
        let userIDData = Data(userID.utf8)
        let salt = try await TIP.salt(pin: pin)
        let mnemonics = try MixinMnemonics(entropy: salt)
        let masterKey = try MasterKey.key(from: mnemonics)
        let publicKey = masterKey.publicKey.rawRepresentation.hexEncodedString()
        let signature = try masterKey.signature(for: userIDData).hexEncodedString()
        
        self.userID = userID
        self.pin = pin
        self.mnemonics = mnemonics
        self.publicKey = publicKey
        self.signature = signature
    }
    
}
