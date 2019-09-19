import Foundation

class RotateSignedPreKeyJob: BaseJob {

    override func getJobId() -> String {
        return "rotate-signed-prekey"
    }

    override func run() throws {
        let signedPrekeyOffset = CryptoUserDefault.shared.signedPrekeyOffset
        do {
            let identityKeyPair = try PreKeyUtil.getIdentityKeyPair()
            let signedPreKey = try PreKeyUtil.generateSignedPreKey(identityKeyPair: identityKeyPair)
            let request = SignalKeyRequest(identityKey: identityKeyPair.publicKey.base64EncodedString(),
                                           signedPreKey: SignedPreKeyRequest(signed: signedPreKey),
                                           oneTimePreKeys: nil)
            _ = SignalKeyAPI.shared.pushSignalKeys(key: request)
            FileManager.default.writeLog(log: "[RotateSignedPreKeyJob]...signedPrekeyOffset:\(signedPrekeyOffset)->\(CryptoUserDefault.shared.signedPrekeyOffset)")
        } catch {
            if let err = error as? SignalError, err == SignalError.noData, IdentityDAO.shared.getLocalIdentity() == nil {
                var userInfo = UIApplication.getTrackUserInfo()
                userInfo["error"] = "local identity nil"
                userInfo["signedOldPrekeyOffset"] = "\(signedPrekeyOffset)"
                userInfo["signedNewPrekeyOffset"] = "\(CryptoUserDefault.shared.signedPrekeyOffset)"
                userInfo["identityCount"] = "\(IdentityDAO.shared.getCount())"
                UIApplication.traceError(code: ReportErrorCode.logoutError, userInfo: userInfo)
                AccountAPI.shared.logout(from: "RotateSignedPreKeyJob")
            } else {
                UIApplication.traceError(error)
            }
        }
    }

}
