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
        let participantIds: [String] = participants.map { (participant) in
            if participant.userAvatarUrl.isEmpty {
                return String(participant.userFullName.prefix(1))
            } else {
                return participant.userAvatarUrl
            }
        }
        let imageFile = conversationId + "-" + participantIds.joined().md5() + ".png"
        let imageUrl = AppGroupContainer.groupIconsUrl.appendingPathComponent(imageFile)
        guard !FileManager.default.fileExists(atPath: imageUrl.path) else {
            updateAndRemoveOld(conversationId: conversationId, imageFile: imageFile)
            return false
        }
        guard let groupImage = GroupIconMaker.make(participants: participants) else {
            return false
        }

        do {
            try? FileManager.default.removeItem(atPath: imageUrl.path)
            if let data = groupImage.pngData() {
                try data.write(to: imageUrl)
                updateAndRemoveOld(conversationId: conversationId, imageFile: imageFile)
            }
        } catch {
            Reporter.report(error: error)
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
        NotificationCenter.default.postOnMain(name: .ConversationDidChange, object: change)
    }

}
