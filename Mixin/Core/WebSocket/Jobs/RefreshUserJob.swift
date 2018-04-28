import Foundation

class RefreshUserJob: BaseJob {

    private let updateParticipantStatus: Bool
    private let jobId: String
    private let userIds: [String]

    init(userIds: [String], updateParticipantStatus: Bool = false) {
        self.userIds = userIds
        self.updateParticipantStatus = updateParticipantStatus
        jobId = userIds.sorted().joined(separator: ",").md5()
    }

    override func getJobId() -> String {
        return "refresh-user-\(jobId)"
    }

    override func shouldRetry(error: JobError) -> Bool {
        if case let .clientError(code) = error, code == 404, userIds.count == 1 {
            processNotFoundUser(userId: userIds[0])
            return false
        } else {
            return super.shouldRetry(error: error)
        }
    }

    override func run() throws {
        guard userIds.count > 0 else {
            return
        }

        if userIds.count == 1 {
            guard !userIds[0].isEmpty else {
                return
            }
            switch UserAPI.shared.showUser(userId: userIds[0]) {
                case let .success(response):
                    UserDAO.shared.updateUsers(users: [response], updateParticipantStatus: updateParticipantStatus)
                case let .failure(error):
                    throw error
            }
        } else {
            switch UserAPI.shared.showUsers(userIds: userIds) {
            case let .success(users):
                if users.count != userIds.count {
                    let serverUserIds: [String] = users.flatMap({ (user) -> String in
                        return user.userId
                    })
                    for userId in userIds {
                        if !serverUserIds.contains(userId) {
                            processNotFoundUser(userId: userId)
                        }
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

