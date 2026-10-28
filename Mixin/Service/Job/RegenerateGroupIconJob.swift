import Foundation
import UIKit
import MixinServices

final class RegenerateGroupIconJob: AsynchronousJob {
    
    private let conversationID: String
    
    init(conversationId: String) {
        self.conversationID = conversationId
    }
    
    override func getJobId() -> String {
        "refresh-group-icon-\(conversationID)"
    }
    
    override func execute() -> Bool {
        let iconURL = ConversationDAO.shared.iconURL(conversationID: conversationID)
        if Conversation.groupIconType(iconURL: iconURL) == .remote {
            finishJob()
            return true
        }
        
        let participants = ParticipantDAO.shared.getGroupIconParticipants(conversationId: conversationID)
        guard participants.count >= 4 || participants.count == ParticipantDAO.shared.getParticipantCount(conversationId: conversationID) else {
            return false
        }
        guard let image = GroupIconMaker.make(participants: participants) else {
            return false
        }
        do {
            let filename = try GroupIconSaver.save(
                image: image,
                forGroupWith: conversationID,
                participants: participants
            )
            updateAndRemoveOld(conversationID: conversationID, imageFile: filename)
        } catch let GroupIconSaver.Error.fileExists(filename) {
            updateAndRemoveOld(conversationID: conversationID, imageFile: filename)
            return false
        } catch {
            reporter.report(error: error)
        }
        finishJob()
        return true
    }
    
    private func updateAndRemoveOld(conversationID: String, imageFile: String) {
        let updateSuccess = ConversationDAO.shared.updateGeneratedGroupIcon(
            conversationID: conversationID,
            filename: imageFile
        )
        if !updateSuccess {
            let url = AppGroupContainer.groupIconsUrl.appendingPathComponent(imageFile)
            try? FileManager.default.removeItem(at: url)
        }
    }
    
}
