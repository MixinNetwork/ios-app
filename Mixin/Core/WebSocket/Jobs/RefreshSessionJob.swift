import Foundation

class RefreshSessionJob: BaseJob {

    let conversationId: String
    let userId: String

    init(conversationId: String, userId: String) {
        self.conversationId = conversationId
        self.userId = userId
    }

    override func getJobId() -> String {
        return "refresh-session-\(conversationId)-\(userId)"
    }

    override func run() throws {
        switch UserAPI.shared.fetchSessions(userIds: [userId]) {
        case let .success(sessions):
            let participantSessions = sessions.map {
                 ParticipantSession(conversationId: conversationId, userId: $0.userId, sessionId: $0.sessionId, sentToServer: nil, createdAt: Date().toUTCString())
            }
            MixinDatabase.shared.insertOrReplace(objects: participantSessions)
        case let .failure(error):
            guard error.code != 401 else {
                return
            }
            throw error
        }
    }
}
