import Foundation

class RotateSignedPreKeyJob: BaseJob {

    override func getJobId() -> String {
        return "rotate-signed-prekey"
    }

    override func run() throws {
        do {
            let identityKeyPair = try PreKeyUtil.getIdentityKeyPair()

            let signedPreKey = try PreKeyUtil.generateSignedPreKey(identityKeyPair: identityKeyPair)

            let request = SignalKeyRequest(identityKey: identityKeyPair.publicKey.base64EncodedString(),
                                           signedPreKey: SignedPreKeyRequest(signed: signedPreKey),
                                           oneTimePreKeys: nil)
            _ = SignalKeyAPI.shared.pushSignalKeys(key: request)
        } catch {
            if let err = error as? SignalError, err == SignalError.noData, IdentityDao.shared.getLocalIdentity() == nil {
                var userInfo = UIApplication.getTrackUserInfo()
                userInfo["error"] = "local identity nil"
                userInfo["identityCount"] = "\(IdentityDao.shared.getCount())"
                UIApplication.traceError(code: ReportErrorCode.logoutError, userInfo: userInfo)
                AccountAPI.shared.logout()
            } else {
                UIApplication.traceError(error)
            }
        }
    }

}
