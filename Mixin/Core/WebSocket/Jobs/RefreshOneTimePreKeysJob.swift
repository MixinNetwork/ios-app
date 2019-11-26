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
            FileManager.default.writeLog(log: "[RefreshOneTimePreKeysJob]...\(Bundle.main.shortVersion)(\(Bundle.main.bundleVersion))")
        } catch {
            if let err = error as? SignalError, IdentityDAO.shared.getLocalIdentity() == nil {
                var userInfo = UIApplication.getTrackUserInfo()
                userInfo["signalErrorCode"] = err.rawValue
                userInfo["identityCount"] = "\(IdentityDAO.shared.getCount())"
                userInfo["signalError"] = "local identity nil"
                UIApplication.traceError(code: ReportErrorCode.logoutError, userInfo: userInfo)
                AccountAPI.shared.logout(from: "RefreshOneTimePreKeysJob")
            } else {
                UIApplication.traceError(error)
            }
        }
    }
}
