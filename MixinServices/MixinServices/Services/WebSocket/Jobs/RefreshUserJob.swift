import Foundation

public class RefreshUserJob: BaseJob {
    
    private let updateParticipantStatus: Bool
    private let jobId: String
    private let userIds: [String]
    
    public init(userIds: [String], updateParticipantStatus: Bool = false) {
        self.userIds = userIds
        self.updateParticipantStatus = updateParticipantStatus
        jobId = userIds.sorted().joined(separator: ",").md5()
    }
    
    override public func getJobId() -> String {
        return "refresh-user-\(jobId)"
    }
    
    override public func run() throws {
        guard userIds.count > 0 else {
            return
        }
        
        if userIds.count == 1 {
            let userId = userIds[0]
            guard !userId.isEmpty && UUID(uuidString: userId) != nil else {
                return
            }
            switch UserAPI.shared.showUser(userId: userId) {
            case let .success(response):
                UserDAO.shared.updateUsers(users: [response], updateParticipantStatus: updateParticipantStatus)
            case let .failure(error):
                guard error.code != 404 else {
                    processNotFoundUser(userId: userId)
                    return
                }
                throw error
            }
        } else {
            switch UserAPI.shared.showUsers(userIds: userIds) {
            case let .success(users):
                if users.count != userIds.count {
                    let serverUserIds = users.map{ $0.userId }
                    for userId in userIds where !serverUserIds.contains(userId) {
                        processNotFoundUser(userId: userId)
                    }
                }
                UserDAO.shared.updateUsers(users: users, updateParticipantStatus: updateParticipantStatus)
            case let .failure(error):
                throw error
            }
        }
    }
    
    private func processNotFoundUser(userId: String) {
        UserDAO.shared.deleteUser(userId: userId)
        if updateParticipantStatus {
            ParticipantDAO.shared.updateParticipantStatus(userId: userId, status: .ERROR)
        }
    }
    
}
