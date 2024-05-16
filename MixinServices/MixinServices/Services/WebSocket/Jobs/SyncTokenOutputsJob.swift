import UIKit

public final class SyncTokenOutputsJob: AsynchronousJob {
    
    enum SyncError: Error {
        case badNetwork
        case encodeMembers
    }
    
    public static let didFinishNotification = Notification.Name("one.mixin.services.SyncTokenOutputsJob.DidFinish")
    public static let errorUserInfoKey = "e"
    
    private let synchronizeOutputPageCount = 200
    private let assetID: String
    private let kernelAssetID: String
    
    public init(assetID: String, kernelAssetID: String) {
        self.assetID = assetID
        self.kernelAssetID = kernelAssetID
    }
    
    override public func getJobId() -> String {
        "sync-token-outputs"
    }
    
    public override func execute() -> Bool {
        guard LoginManager.shared.isLoggedIn else {
            return false
        }
        guard ReachabilityManger.shared.isReachable else {
            NotificationCenter.default.post(onMainThread: Self.didFinishNotification,
                                            object: self,
                                            userInfo: [Self.errorUserInfoKey: SyncError.badNetwork])
            return false
        }
        let limit = self.synchronizeOutputPageCount
        Task { [assetID, kernelAssetID] in
            defer {
                self.finishJob()
            }
            guard let userID = LoginManager.shared.account?.userID else {
                return
            }
            guard let data = userID.data(using: .utf8), let membersHash = SHA3_256.hash(data: data) else {
                NotificationCenter.default.post(onMainThread: Self.didFinishNotification,
                                                object: self,
                                                userInfo: [Self.errorUserInfoKey: SyncError.encodeMembers])
                return
            }
            let members = membersHash.hexEncodedString()
            
            var outputs: [Output] = []
            var sequence = OutputDAO.shared.latestOutputSequence(asset: kernelAssetID)
            
            do {
                repeat {
                    outputs = try await SafeAPI.outputs(members: members,
                                                        threshold: 1,
                                                        offset: sequence,
                                                        limit: limit,
                                                        state: Output.State.unspent.rawValue,
                                                        asset: kernelAssetID)
                    guard let lastOutput = outputs.last else {
                        break
                    }
                    OutputDAO.shared.insert(outputs: outputs, onConflict: .replace) { db in
                        try UTXOService.shared.updateBalance(assetID: assetID, 
                                                             kernelAssetID: kernelAssetID,
                                                             db: db)
                    }
                    sequence = lastOutput.sequence
                } while outputs.count >= limit && LoginManager.shared.isLoggedIn
            } catch MixinAPIResponseError.unauthorized {
                return
            } catch {
                NotificationCenter.default.post(onMainThread: Self.didFinishNotification,
                                                object: self,
                                                userInfo: [Self.errorUserInfoKey: error])
            }
            NotificationCenter.default.post(onMainThread: Self.didFinishNotification, object: self)
        }
        return true
    }
    
}
