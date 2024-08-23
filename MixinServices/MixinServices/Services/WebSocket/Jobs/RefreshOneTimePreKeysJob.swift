import Foundation

public class RefreshOneTimePreKeysJob: BaseJob {
    
    override public func getJobId() -> String {
        return "onetime-prekey"
    }
    
    override public func run() throws {
        guard case let .success(response) = SignalKeyAPI.getSignalKeyCount() else {
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
            _ = SignalKeyAPI.pushSignalKeys(key: request)
            Logger.general.info(category: "RefreshOneTimePreKeysJob", message: "Refreshing for app \(Bundle.main.shortVersionString)(\(Bundle.main.bundleVersion))")
        } catch let error as SignalError where IdentityDAO.shared.getLocalIdentity() == nil {
            let error = MixinServicesError.refreshOneTimePreKeys(error: error, identityCount: IdentityDAO.shared.getCount())
            reporter.report(error: error)
            LoginManager.shared.logout(reason: "RefreshOneTimePreKeysJob: \(error)")
        } catch {
            reporter.report(error: error)
        }
    }
    
}
