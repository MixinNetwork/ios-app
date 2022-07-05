import Foundation
import MixinServices

class RefreshOffsetJob: BaseJob {

    override func getJobId() -> String {
        return "refresh-offset"
    }

    override func run() throws {
        var statusOffset = AppGroupUserDefaults.Crypto.Offset.status
        repeat {
            guard LoginManager.shared.isLoggedIn else {
                return
            }
            switch MessageAPI.messageStatus(offset: statusOffset) {
            case let .success(blazeMessages):
                guard let lastStatusOffset = blazeMessages.last?.updatedAt.toUTCDate().nanosecond() else {
                    return
                }
                ReceiveMessageService.shared.withManagedMessageProcessing {
                    var statuses: [String: String] = [:]
                    for data in blazeMessages {
                        let messageExists = MessageDAO.shared.updateMessageStatus(messageId: data.messageId, status: data.status, from: "RefreshOffset")
                        AppGroupUserDefaults.Crypto.Offset.status = data.updatedAt.toUTCDate().nanosecond()
                        if !messageExists {
                            statuses[data.messageId] = data.status
                            Logger.general.debug(category: "RefreshOffsetJob", message: "Saved status for inexisted message: \(data.messageId), status: \(data.status)")
                        }
                    }
                    return statuses
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
