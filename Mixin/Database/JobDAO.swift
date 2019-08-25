import Foundation
import WCDBSwift

final class JobDAO {

    static let shared = JobDAO()

    func nextJob() -> Job? {
        return MixinDatabase.shared.getCodables(orderBy: [Job.Properties.priority.asOrder(by: .descending), Job.Properties.isSessionMessage.asOrder(by: .ascending), Job.Properties.orderId.asOrder(by: .ascending)], limit: 1).first
    }

    func clearSessionJob() {
        MixinDatabase.shared.delete(table: Job.tableName, condition: Job.Properties.action == JobAction.SEND_SESSION_MESSAGE.rawValue)
    }

    func nextBatchAckJobs(limit: Limit) -> [Job] {
        return MixinDatabase.shared.getCodables(condition: Job.Properties.action == JobAction.SEND_ACK_MESSAGE.rawValue || Job.Properties.action == JobAction.SEND_DELIVERED_ACK_MESSAGE.rawValue, orderBy: [Job.Properties.orderId.asOrder(by: .ascending)], limit: limit)
    }

    func nextBatchJobs(action: JobAction, limit: Limit) -> [Job] {
        return MixinDatabase.shared.getCodables(condition: Job.Properties.action == action.rawValue, orderBy: [Job.Properties.orderId.asOrder(by: .ascending)], limit: limit)
    }

    func getCount() -> Int {
        return MixinDatabase.shared.getCount(on: Job.Properties.jobId.count(), fromTable: Job.tableName)
    }

    func removeJob(jobId: String) {
        MixinDatabase.shared.delete(table: Job.tableName, condition: Job.Properties.jobId == jobId)
    }

    func removeJobs(jobIds: [String]) {
        MixinDatabase.shared.delete(table: Job.tableName, condition: Job.Properties.jobId.in(jobIds))
    }
}
