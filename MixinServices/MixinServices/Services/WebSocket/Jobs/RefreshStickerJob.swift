import Foundation

public class RefreshStickerJob: BaseJob {
    
    private let stickerId: String
    
    public init(stickerId: String) {
        self.stickerId = stickerId
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
        case let .failure(error):
            if error.worthReporting {
                reporter.report(error: error)
            }
        }
    }
    
}
