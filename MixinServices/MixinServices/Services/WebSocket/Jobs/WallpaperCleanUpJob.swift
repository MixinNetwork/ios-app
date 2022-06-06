import UIKit

public class WallpaperCleanUpJob: BaseJob {
    
    let conversationId: String
    
    public init(conversationId: String) {
        self.conversationId = conversationId
    }
    
    override open func getJobId() -> String {
        "cleanup-wallpaper-\(conversationId)"
    }
    
    override open func run() throws {
        AppGroupUserDefaults.User.wallpapers[conversationId] = nil
        let url = AttachmentContainer.wallpaperURL(for: conversationId)
        try? FileManager.default.removeItem(at: url)
    }
    
}
