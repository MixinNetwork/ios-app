import Foundation
import UIKit

public class RefreshConversationJob: BaseJob {
    
    let conversationId: String
    
    public init(conversationId: String) {
        self.conversationId = conversationId
    }
    
    override public func getJobId() -> String {
        return "refresh-coversation-\(conversationId)"
    }
    
    override public func run() throws {
        guard !conversationId.isEmpty && conversationId != User.systemUser && conversationId != myUserId else {
            return
        }
        
        guard let conversationStatus = ConversationDAO.shared.getConversationStatus(conversationId: conversationId) else {
            return
        }

        if conversationStatus == ConversationStatus.START.rawValue {
            let category = ConversationDAO.shared.getConversationCategory(conversationId: conversationId) ?? ""
            if category.isEmpty {
                try updateConversation(conversationStatus)
            } else if let conversation = ConversationDAO.shared.getConversation(conversationId: conversationId) {
                try createConversation(conversation: conversation)
            }
        } else {
            try updateConversation(conversationStatus)
        }
    }
    
    private func createConversation(conversation: ConversationItem) throws {
        var participants = ParticipantDAO.shared.participantRequests(conversationId: conversation.conversationId, currentAccountId: currentAccountId)
        if participants.count == 0 && conversation.category == ConversationCategory.CONTACT.rawValue && conversation.ownerId != currentAccountId {
            participants = [ParticipantRequest(userId: conversation.ownerId, role: "")]
        }
        guard participants.count > 0 else {
            ConversationDAO.shared.deleteChat(conversationId: conversationId)
            return
        }
        
        let name = conversation.category == ConversationCategory.CONTACT.rawValue ? nil : conversation.name
        let request = ConversationRequest(conversationId: conversation.conversationId, name: name, category: conversation.category, participants: participants, duration: nil, announcement: nil)
        
        switch ConversationAPI.shared.createConversation(conversation: request) {
        case let .success(response):
            ConversationDAO.shared.createConversation(conversation: response, targetStatus: ConversationStatus.SUCCESS)
        case let.failure(error):
            throw error
        }
    }
    
    private func updateConversation(_ status: Int) throws {
        switch ConversationAPI.shared.getConversation(conversationId: conversationId) {
        case let .success(response):
            if status == ConversationStatus.START.rawValue {
                ConversationDAO.shared.createConversation(conversation: response, targetStatus: ConversationStatus.SUCCESS)
            } else {
                ConversationDAO.shared.updateConversation(conversation: response)
            }
            CircleConversationDAO.shared.update(conversation: response)
        case let .failure(error):
            if error.code == 404 || error.code == 403 {
                ConversationDAO.shared.exitGroup(conversationId: conversationId)
            } else {
                throw error
            }
        }
    }
    
}
