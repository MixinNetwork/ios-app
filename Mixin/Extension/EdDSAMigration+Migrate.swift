import Foundation
import MixinServices

extension EdDSAMigration {
    
    static func migrate() {
        let key = Ed25519PrivateKey()
        let sessionSecret = key.publicKey.rawRepresentation.base64EncodedString()

        repeat {
            guard LoginManager.shared.isLoggedIn else {
                return
            }
            let result = AccountAPI.update(sessionSecret: sessionSecret)
            switch result {
            case .success(let response):
                guard
                    let remotePublicKey = Data(base64Encoded: response.pinToken),
                    let pinToken = AgreementCalculator.agreement(publicKey: remotePublicKey, privateKey: key.x25519Representation)
                else {
                    AppGroupKeychain.removeItemsForCurrentSession()
                    reporter.report(error: MixinAPIError.invalidServerPinToken)
                    return
                }
                AppGroupUserDefaults.Account.sessionSecret = nil
                AppGroupUserDefaults.Account.pinToken = nil
                AppGroupKeychain.sessionSecret = key.rawRepresentation
                AppGroupKeychain.pinToken = pinToken
                return
            case .failure(.unauthorized), .failure(.forbidden):
                AppGroupKeychain.removeItemsForCurrentSession()
                return
            case let .failure(error) where error.worthRetrying:
                reporter.report(error: error)
                Thread.sleep(forTimeInterval: 2)
            case let .failure(error):
                reporter.report(error: error)
                AppGroupKeychain.removeItemsForCurrentSession()
                return
            }
        } while true
    }
    
}
