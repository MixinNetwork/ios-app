import Foundation

public final class RefreshInscriptionJob: AsynchronousJob {
    
    public enum UserInfoKey {
        public static let item = "i"
        public static let snapshotID = "s"
    }
    
    public static let didFinishedNotification = Notification.Name("one.mixin.service.RefreshInscirption")
    
    public var messageID: String?
    public var snapshotID: String?
    
    private let inscriptionHash: String
    
    public init(inscriptionHash: String) {
        self.inscriptionHash = inscriptionHash
    }
    
    override public func getJobId() -> String {
        "refresh-inscription-" + inscriptionHash
    }
    
    public override func execute() -> Bool {
        Task.detached { [inscriptionHash, messageID, snapshotID] in
            let item = try await InscriptionItem.retrieve(inscriptionHash: inscriptionHash)
            if let messageID, let content = item.asMessageContent() {
                MessageDAO.shared.update(content: content, forMessageWith: messageID)
            }
            var userInfo: [String: Any] = [Self.UserInfoKey.item: item]
            if let snapshotID {
                userInfo[Self.UserInfoKey.snapshotID] = snapshotID
            }
            NotificationCenter.default.post(onMainThread: Self.didFinishedNotification,
                                            object: self,
                                            userInfo: userInfo)
            self.finishJob()
        }
        return true
    }
    
}
