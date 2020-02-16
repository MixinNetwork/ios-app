import UIKit
import MixinServices

class CleanUpUnusedAttachmentJob: BaseJob {

    override func getJobId() -> String {
       "clean_up_unused_attachment"
    }

    override func run() throws {
        guard -AppGroupUserDefaults.User.lastAttachmentCleanUpDate.timeIntervalSinceNow >= 86400 * 7 else {
            return
        }

        let categories: [AttachmentContainer.Category] = [.photos, .audios, .files, .videos]
        
        for category in categories {
            let path = AttachmentContainer.url(for: category, filename: nil).path
            guard let onDiskFilenames = try? FileManager.default.contentsOfDirectory(atPath: path), onDiskFilenames.count > 0 else {
                continue
            }

            if category == .videos {
                let referencedFilenames = MessageDAO.shared
                    .getMediaUrls(categories: category.messageCategory)
                    .map({ NSString(string: $0).deletingPathExtension })
                for onDiskFilename in onDiskFilenames where !referencedFilenames.contains(where: { onDiskFilename.contains($0) }) {
                    let url = AttachmentContainer.url(for: .videos, filename: onDiskFilename)
                    try? FileManager.default.removeItem(at: url)
                }
            } else {
                let referencedFilenames = Set(MessageDAO.shared.getMediaUrls(categories: category.messageCategory))
                for onDiskFilename in onDiskFilenames where !referencedFilenames.contains(onDiskFilename) {
                    let url = AttachmentContainer.url(for: category, filename: onDiskFilename)
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }

        AppGroupUserDefaults.User.lastAttachmentCleanUpDate = Date()
    }
}
