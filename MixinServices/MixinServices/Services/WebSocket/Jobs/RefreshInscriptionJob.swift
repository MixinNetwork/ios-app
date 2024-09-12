import Foundation
import AppCenterCrashes

public final class RefreshInscriptionJob: BaseJob {
    
    public enum UserInfoKey {
        public static let item = "i"
        public static let snapshotID = "s"
    }
    
    public static let didFinishNotification = Notification.Name("one.mixin.service.RefreshInscirption")
    
    public var messageID: String?
    public var snapshotID: String?
    
    private let inscriptionHash: String
    
    public init(inscriptionHash: String) {
        self.inscriptionHash = inscriptionHash
    }
    
    override public func getJobId() -> String {
        "refresh-inscription-" + inscriptionHash
    }
    
    public override func run() throws {
        Logger.general.debug(category: "Inscription", message: "Load \(inscriptionHash), mid: \(messageID), sid: \(snapshotID)")
        repeat {
            guard LoginManager.shared.isLoggedIn else {
                return
            }
            do {
                let result = InscriptionItem.fetchAndSave(inscriptionHash: inscriptionHash)
                switch result {
                case .success(let item):
                    Logger.general.info(category: "Inscription", message: "\(inscriptionHash) success")
                    if let messageID, let content = item.asMessageContent() {
                        Logger.general.info(category: "Inscription", message: "\(inscriptionHash) message updated")
                        MessageDAO.shared.update(content: content, forMessageWith: messageID)
                    }
                    var userInfo: [String: Any] = [Self.UserInfoKey.item: item]
                    if let snapshotID {
                        userInfo[Self.UserInfoKey.snapshotID] = snapshotID
                    }
                    NotificationCenter.default.post(onMainThread: Self.didFinishNotification,
                                                    object: self,
                                                    userInfo: userInfo)
                    return
                case .failure(let error):
                    if error.worthRetrying {
                        Logger.general.debug(category: "Inscription", message: "Reload after 3s")
                        Thread.sleep(forTimeInterval: 3)
                        continue
                    } else {
                        let description = "\(error)"
                        Logger.general.error(category: "Inscription", message: description)
                        Crashes.trackError(error, properties: ["error": description], attachments: nil)
                    }
                }
            }
        } while true
    }
    
}
