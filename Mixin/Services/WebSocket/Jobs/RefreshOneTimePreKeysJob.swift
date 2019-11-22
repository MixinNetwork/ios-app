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
            Logger.write(log: "[RefreshOneTimePreKeysJob]...\(Bundle.main.shortVersion)(\(Bundle.main.bundleVersion))")
        } catch let error as SignalError where IdentityDAO.shared.getLocalIdentity() == nil {
            let error = MixinServicesError.refreshOneTimePreKeys(error: error, identityCount: IdentityDAO.shared.getCount())
            Reporter.report(error: error)
            AccountAPI.shared.logout(from: "RefreshOneTimePreKeysJob")
        } catch {
            Reporter.report(error: error)
        }
    }
}
