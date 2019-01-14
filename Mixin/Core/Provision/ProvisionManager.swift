import Foundation

class ProvisionManager {
    
    private(set) static var isDesktopLoggedIn = false
    
    static func updateProvision(uuid: String, base64EncodedPublicKey: String, completion: @escaping (Bool) -> Void) {
        guard !isDesktopLoggedIn else {
            alert("Already logged in")
            return
        }
        let cryptor = MXNProvisionCryptor(signalContext: Signal.context,
                                          base64EncodedPublicKey: base64EncodedPublicKey)
        let identityKeyPair = PreKeyUtil.getIdentityKeyPair()
        guard let profileKey = ProfileKeyUtil.profileKey else {
            alert("Empty profileKey")
            return
        }
        ProvisioningAPI.shared.code { (response) in
            switch response {
            case .success(let response):
                let account = AccountAPI.shared.account!
                let message = ProvisionMessage(identityKeyPublic: identityKeyPair.publicKey,
                                               identityKeyPrivate: identityKeyPair.privateKey,
                                               userId: account.user_id,
                                               sessionId: account.session_id,
                                               provisioningCode: response.code,
                                               profileKey: profileKey)
                guard let secretData = cryptor.encryptedData(from: message) else {
                    alert("Empty secretData")
                    return
                }
                let secret = secretData.base64EncodedString()
                ProvisioningAPI.shared.update(id: uuid, secret: secret, completion: { (result) in
                    switch result {
                    case .success(let reponse):
                        isDesktopLoggedIn = true
                        completion(true)
                    case .failure(let error):
                        isDesktopLoggedIn = false
                        alert(error.localizedDescription)
                        completion(false)
                    }
                })
            case .failure:
                isDesktopLoggedIn = false
                alert("failed to get code")
                completion(false)
            }
        }

    }
    
    static func alert(_ str: String) {
        AppDelegate.current.window?.rootViewController?.alert(str)
    }
    
}
