import Foundation

public final class RefreshInscirptionJob: AsynchronousJob {
    
    public static let didFinishedNotification = Notification.Name("one.mixin.service.RefreshInscirption")
    public static let dataUserInfoKey = "d"
    
    private let inscriptionHash: String
    private let messageID: String?
    
    public init(inscriptionHash: String, messageID: String?) {
        self.inscriptionHash = inscriptionHash
        self.messageID = messageID
    }
    
    override public func getJobId() -> String {
        "refresh-inscription-" + inscriptionHash
    }
    
    public override func execute() -> Bool {
        Task.detached { [inscriptionHash, messageID] in
            let item = try await InscriptionItem.retrieve(inscriptionHash: inscriptionHash)
            if let messageID, let content = item.asMessageContent() {
                MessageDAO.shared.update(content: content, forMessageWith: messageID)
            }
            NotificationCenter.default.post(onMainThread: Self.didFinishedNotification,
                                            object: self,
                                            userInfo: [Self.dataUserInfoKey: item])
        }
        return true
    }
    
}
