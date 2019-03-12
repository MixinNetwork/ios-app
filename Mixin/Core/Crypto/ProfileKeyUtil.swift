import Foundation

class ProfileKeyUtil {
    
    static var profileKey: Data? {
        if CryptoUserDefault.shared.profileKey == nil {
            CryptoUserDefault.shared.profileKey = Data(withSecuredRandomBytesOfCount: 32)
        }
        return Data(withSecuredRandomBytesOfCount: 32)
    }
    
    static func rotate() {
        CryptoUserDefault.shared.profileKey = nil
    }
    
}
