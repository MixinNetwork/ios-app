import Foundation
import WCDBSwift

final class JobDAO {

    static let shared = JobDAO()

    func addJobs(jobs: [Job]) {
        JobDatabase.getIntance().insert(objects: jobs)
    }

    func nextJob() -> Job? {
        return JobDatabase.getIntance().getCodables(orderBy: [Job.Properties.priority.asOrder(by: .descending), Job.Properties.orderId.asOrder(by: .ascending)], limit: 1).first
    }

    func clearSessionJob() {
        JobDatabase.getIntance().delete(table: Job.tableName, condition: Job.Properties.action == JobAction.SEND_SESSION_MESSAGE.rawValue)
    }

    func nextBatchAckJobs(limit: Limit) -> [Job] {
        return JobDatabase.getIntance().getCodables(condition: Job.Properties.action == JobAction.SEND_ACK_MESSAGE.rawValue || Job.Properties.action == JobAction.SEND_DELIVERED_ACK_MESSAGE.rawValue, orderBy: [Job.Properties.orderId.asOrder(by: .ascending)], limit: limit)
    }

    func nextBatchJobs(action: JobAction, limit: Limit) -> [Job] {
        return JobDatabase.getIntance().getCodables(condition: Job.Properties.action == action.rawValue, orderBy: [Job.Properties.orderId.asOrder(by: .ascending)], limit: limit)
    }

    func getCount() -> Int {
        return JobDatabase.getIntance().getCount(on: Job.Properties.jobId.count(), fromTable: Job.tableName)
    }

    func removeJob(jobId: String) {
        JobDatabase.getIntance().delete(table: Job.tableName, condition: Job.Properties.jobId == jobId)
    }

    func removeJobs(jobIds: [String]) {
        JobDatabase.getIntance().delete(table: Job.tableName, condition: Job.Properties.jobId.in(jobIds))
    }
}
