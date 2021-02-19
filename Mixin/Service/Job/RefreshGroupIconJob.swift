import Foundation
import UIKit
import SDWebImage
import MixinServices

class RefreshGroupIconJob: AsynchronousJob {

    let conversationId: String

    init(conversationId: String) {
        self.conversationId = conversationId
    }

    override func getJobId() -> String {
        return "refresh-group-icon-\(conversationId)"
    }

    override func execute() -> Bool {
        let participants = ParticipantDAO.shared.getGroupIconParticipants(conversationId: conversationId)
        guard participants.count >= 4 || participants.count == ParticipantDAO.shared.getParticipantCount(conversationId: conversationId) else {
            return false
        }
        guard let image = GroupIconMaker.make(participants: participants) else {
            return false
        }
        do {
            let filename = try GroupIconSaver.save(image: image,
                                                   forGroupWith: conversationId,
                                                   participants: participants)
            updateAndRemoveOld(conversationId: conversationId, imageFile: filename)
        } catch let GroupIconSaver.Error.fileExists(filename) {
            updateAndRemoveOld(conversationId: conversationId, imageFile: filename)
            return false
        } catch {
            reporter.report(error: error)
        }

        finishJob()
        return true
    }

    private func updateAndRemoveOld(conversationId: String, imageFile: String) {
        let oldIconUrl = ConversationDAO.shared.getConversationIconUrl(conversationId: conversationId)
        ConversationDAO.shared.updateIconUrl(conversationId: conversationId, iconUrl: imageFile)
        if let removeIconUrl = oldIconUrl, !removeIconUrl.isEmpty, removeIconUrl != imageFile {
            try? FileManager.default.removeItem(atPath: AppGroupContainer.groupIconsUrl.appendingPathComponent(removeIconUrl).path)
        }
        let change = ConversationChange(conversationId: conversationId, action: .updateGroupIcon(iconUrl: imageFile))
        NotificationCenter.default.post(onMainThread: MixinServices.conversationDidChangeNotification, object: change)
    }

}
