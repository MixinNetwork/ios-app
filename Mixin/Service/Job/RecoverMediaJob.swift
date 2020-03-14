import Foundation
import MixinServices

class RecoverMediaJob: BaseJob {

    override func getJobId() -> String {
       "recover_media"
    }

    override func run() throws {
        guard AppGroupUserDefaults.User.hasRecoverMedia else {
            return
        }

        let categories: [AttachmentContainer.Category] = [.photos, .audios, .files, .videos]

        for category in categories {
            var offset = 0
            var mediaUrls = [String: String]()
            repeat {
                var pendingMessageIds = [String]()
                mediaUrls = MessageDAO.shared.getDownloadedMediaUrls(categories: category.messageCategory, offset: offset, limit: 100)

                for (messageId, mediaUrl) in mediaUrls where !FileManager.default.isAvailable(AttachmentContainer.url(for: category, filename: mediaUrl).path) {
                    pendingMessageIds.append(messageId)
                }

                if pendingMessageIds.count > 0 {
                    SendMessageService.shared.recoverAttachmentMessages(messageIds: pendingMessageIds)
                }

                offset += 100
            } while mediaUrls.count == 100 && LoginManager.shared.isLoggedIn && !MixinService.isStopProcessMessages
        }

        AppGroupUserDefaults.User.hasRecoverMedia = false
    }

}
