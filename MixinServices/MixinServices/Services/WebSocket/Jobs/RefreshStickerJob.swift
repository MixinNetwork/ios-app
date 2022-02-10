import Foundation

public class RefreshStickerJob: AsynchronousJob {
    
    private let stickerId: String
    
    public init(stickerId: String) {
        self.stickerId = stickerId
    }
    
    override public func getJobId() -> String {
        "refresh-sticker-\(stickerId)"
    }
    
    public override func execute() -> Bool {
        defer {
            finishJob()
        }
        switch StickerAPI.sticker(stickerId: stickerId) {
        case let .success(sticker):
            guard !MixinService.isStopProcessMessages else {
                return true
            }
            guard let stickerItem = StickerDAO.shared.insertOrUpdateSticker(sticker: sticker) else {
                return true
            }
            StickerPrefetcher.prefetch(stickers: [stickerItem])
        case let .failure(error):
            reporter.report(error: error)
        }
        return true
    }
    
}
