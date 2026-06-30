import Foundation

public class RefreshStickerJob: BaseJob {
    
    public static let didUpdateNotification = Notification.Name("one.mixin.messenger.RefreshStickerJob.Update")
    
    public enum UserInfoKey {
        public static let sticker = "sticker"
        public static let messageId = "mid"
    }
    
    private let stickerId: String
    private let messageId: String?
    
    public init(stickerId: String, messageId: String?) {
        self.stickerId = stickerId
        self.messageId = messageId
    }
    
    override public func getJobId() -> String {
        "refresh-sticker-\(stickerId)"
    }
    
    public override func run() throws {
        switch StickerAPI.sticker(stickerId: stickerId) {
        case let .success(sticker):
            guard !MixinService.isStopProcessMessages else {
                return
            }
            guard let stickerItem = StickerDAO.shared.insertOrUpdateSticker(sticker: sticker) else {
                return
            }
            StickerPrefetcher.prefetch(stickers: [stickerItem])
            if let messageId {
                let userInfo: [String: Any] = [
                    Self.UserInfoKey.sticker: stickerItem,
                    Self.UserInfoKey.messageId: messageId
                ]
                NotificationCenter.default.post(onMainThread: Self.didUpdateNotification,
                                                object: self,
                                                userInfo: userInfo)
            }
        case let .failure(error):
            if error.worthReporting {
                reporter.report(error: error)
            }
        }
    }
    
}
