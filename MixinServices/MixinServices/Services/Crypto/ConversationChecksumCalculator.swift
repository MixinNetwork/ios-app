import Foundation

enum ConversationChecksumCalculator {
    
    static func checksum(conversationId: String) -> String {
        let sessions = ParticipantSessionDAO.shared.getParticipantSessions(conversationId: conversationId)
        if sessions.isEmpty {
            return ""
        } else {
            return sessions.map(\.sessionId).sorted().joined().md5()
        }
    }
    
}
