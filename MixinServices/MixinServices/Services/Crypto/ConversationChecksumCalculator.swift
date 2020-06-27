import Foundation

enum ConversationChecksumCalculator {
    
    static func checksum(conversationId: String) -> String {
        ParticipantSessionDAO.shared
            .getParticipantSessions(conversationId: conversationId)
            .map(\.sessionId)
            .sorted(by: <)
            .joined()
            .md5()
    }
    
}
