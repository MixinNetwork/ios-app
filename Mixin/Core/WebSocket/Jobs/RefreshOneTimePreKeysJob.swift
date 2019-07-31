import Foundation

class RefreshOneTimePreKeysJob: BaseJob {

    override func getJobId() -> String {
        return "onetime-prekey"
    }

    override func run() throws {
        guard case let .success(response) = SignalKeyAPI.shared.getSignalKeyCount() else {
            return
        }
        guard response.preKeyCount < PreKeyUtil.prekeyMiniNum else {
            return
        }
        refreshKeys()
    }

    private func refreshKeys() {
        do {
            let request = try PreKeyUtil.generateKeys()
            _ = SignalKeyAPI.shared.pushSignalKeys(key: request)
        } catch {
            if let err = error as? SignalError {
                var userInfo = UIApplication.getTrackUserInfo()
                userInfo["signalErrorCode"] = err.rawValue
                userInfo["identityCount"] = "\(IdentityDAO.shared.getCount())"
                if IdentityDAO.shared.getLocalIdentity() == nil {
                    userInfo["signalError"] = "local identity nil"
                    UIApplication.traceError(code: ReportErrorCode.sendMessengerError, userInfo: userInfo)
                    AccountAPI.shared.logout()
                } else {
                    UIApplication.traceError(code: ReportErrorCode.logoutError, userInfo: userInfo)
                }
            } else {
                UIApplication.traceError(error)
            }
        }
    }
}
