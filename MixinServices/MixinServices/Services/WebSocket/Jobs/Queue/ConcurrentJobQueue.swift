import Foundation
import UIKit

public class ConcurrentJobQueue: JobQueue {

    public static let shared = ConcurrentJobQueue()

    init() {
        super.init(maxConcurrentOperationCount: 6)
    }

    func restoreJobs() {
        guard LoginManager.shared.isLoggedIn else {
            return
        }

        DispatchQueue.global().async {
            let startConversationIds = ConversationDAO.shared.getStartStatusConversations()
            for conversationId in startConversationIds {
                ConcurrentJobQueue.shared.addJob(job: RefreshConversationJob(conversationId: conversationId))
            }

            let problemConversationIds = ConversationDAO.shared.getProblemConversations()
            for conversationId in problemConversationIds {
                ConcurrentJobQueue.shared.addJob(job: RefreshConversationJob(conversationId: conversationId))
            }

            let quitConversationIds = ConversationDAO.shared.getQuitStatusConversations()
            for conversationId in quitConversationIds {
                ConcurrentJobQueue.shared.addJob(job: ExitConversationJob(conversationId: conversationId))
            }

            let participantIds = ParticipantDAO.shared.getSyncParticipantIds()
            if participantIds.count > 0 {
                ConcurrentJobQueue.shared.addJob(job: RefreshUserJob(userIds: participantIds, updateParticipantStatus: true))
            }
        }
    }
    
}
