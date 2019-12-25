import Foundation

@objc class ProvisionMessage: NSObject, Codable {
    
    let identityKeyPublic: Data
    let identityKeyPrivate: Data
    let userId: String
    let sessionId: String
    let provisioningCode: String
    let platform = "iOS"
    
    @objc private(set) lazy var jsonData: Data? = {
        return try? JSONEncoder.snakeCase.encode(self)
    }()
    
    init(identityKeyPublic: Data, identityKeyPrivate: Data, userId: String, sessionId: String, provisioningCode: String) {
        self.identityKeyPublic = identityKeyPublic
        self.identityKeyPrivate = identityKeyPrivate
        self.userId = userId
        self.sessionId = sessionId
        self.provisioningCode = provisioningCode
    }
    
}
