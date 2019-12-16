import Foundation
import UIKit

class ConcurrentJobQueue: JobQueue {

    static let shared = ConcurrentJobQueue()

    init() {
        super.init(maxConcurrentOperationCount: 6)
    }

    func restoreJobs() {
        guard AccountAPI.shared.didLogin else {
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

    func sendNotifaction(message: MessageItem) {
        guard message.status == MessageStatus.DELIVERED.rawValue && message.userId != AccountAPI.shared.accountUserId else {
            return
        }

        DispatchQueue.main.async {
            guard message.conversationId != UIApplication.currentConversationId() else {
                return
            }
            guard message.category.hasSuffix("_TEXT") || message.category.hasSuffix("_IMAGE") || message.category.hasSuffix("_STICKER") || message.category.hasSuffix("_CONTACT") || message.category.hasSuffix("_DATA") || message.category.hasSuffix("_VIDEO") || message.category.hasSuffix("_LIVE") || message.category.hasSuffix("_AUDIO") || message.category == MessageCategory.SYSTEM_ACCOUNT_SNAPSHOT.rawValue else {
                return
            }

            ConcurrentJobQueue.shared.addJob(job: ShowNotificationJob(message: message))
        }
    }
    
}
