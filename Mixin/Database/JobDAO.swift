import Foundation
import WCDBSwift

final class JobDAO {

    static let shared = JobDAO()

    func nextJob() -> Job? {
        return MixinDatabase.shared.getCodables(orderBy: [Job.Properties.priority.asOrder(by: .descending), Job.Properties.orderId.asOrder(by: .ascending)], limit: 1).first
    }

    func clearSessionJob() {
        MixinDatabase.shared.delete(table: Job.tableName, condition: Job.Properties.action == JobAction.SEND_SESSION_MESSAGE.rawValue)
    }

    func nextBatchAckJobs(limit: Limit) -> [Job] {
        return MixinDatabase.shared.getCodables(condition: Job.Properties.action == JobAction.SEND_ACK_MESSAGE.rawValue || Job.Properties.action == JobAction.SEND_DELIVERED_ACK_MESSAGE.rawValue, orderBy: [Job.Properties.priority.asOrder(by: .descending), Job.Properties.orderId.asOrder(by: .ascending)], limit: limit)
    }

    func nextBatchJobs(action: JobAction, limit: Limit) -> [Job] {
        return MixinDatabase.shared.getCodables(condition: Job.Properties.action == action.rawValue, orderBy: [Job.Properties.priority.asOrder(by: .descending), Job.Properties.orderId.asOrder(by: .ascending)], limit: limit)
    }

    func getCount() -> Int {
        return MixinDatabase.shared.getCount(on: Job.Properties.jobId.count(), fromTable: Job.tableName)
    }

    func updateJobRunCount(jobId: String, runCount: Int) {
        MixinDatabase.shared.update(maps: [(Job.Properties.runCount, runCount)], tableName: Job.tableName, condition: Job.Properties.jobId == jobId)
    }

    func removeJob(jobId: String) {
        MixinDatabase.shared.delete(table: Job.tableName, condition: Job.Properties.jobId == jobId)
    }

    func removeJobs(jobIds: [String]) {
        MixinDatabase.shared.delete(table: Job.tableName, condition: Job.Properties.jobId.in(jobIds))
    }

    func isExist(conversationId: String, userId: String, action: JobAction) -> Bool {
        return MixinDatabase.shared.isExist(type: Job.self, condition: Job.Properties.conversationId == conversationId && Job.Properties.userId == userId && Job.Properties.action == action.rawValue)
    }
}
