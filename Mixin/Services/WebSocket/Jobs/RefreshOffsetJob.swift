import Foundation

class RefreshOffsetJob: BaseJob {

    override func getJobId() -> String {
        return "refresh-offset"
    }

    override func run() throws {
        var statusOffset = AppGroupUserDefaults.Crypto.Offset.status
        repeat {
            guard AccountAPI.shared.didLogin else {
                return
            }
            switch MessageAPI.shared.messageStatus(offset: statusOffset) {
            case let .success(blazeMessages):
                guard blazeMessages.count > 0, let lastStatusOffset = blazeMessages.last?.updatedAt.toUTCDate().nanosecond() else {
                    return
                }
                for data in blazeMessages {
                    MessageDAO.shared.updateMessageStatus(messageId: data.messageId, status: data.status, from: "messageStatus")
                    AppGroupUserDefaults.Crypto.Offset.status = data.updatedAt.toUTCDate().nanosecond()
                }
                if lastStatusOffset == statusOffset {
                    return
                }
                statusOffset = lastStatusOffset
            case let .failure(error):
                throw error
            }
        } while true
    }

}
