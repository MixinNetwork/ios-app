import Foundation
import WCDBSwift

public final class JobDAO {
    
    static let shared = JobDAO()
    
    func nextJob() -> Job? {
        return MixinDatabase.shared.getCodables(condition: Job.Properties.isHttpMessage == false, orderBy: [Job.Properties.priority.asOrder(by: .descending), Job.Properties.orderId.asOrder(by: .ascending)], limit: 1).first
    }
    
    func clearSessionJob() {
        MixinDatabase.shared.delete(table: Job.tableName, condition: Job.Properties.isHttpMessage == false && (Job.Properties.action == JobAction.SEND_SESSION_MESSAGE.rawValue || Job.Properties.action == JobAction.SEND_SESSION_MESSAGES.rawValue))
    }
    
    func nextBatchHttpJobs(limit: Limit) -> [Job] {
        return MixinDatabase.shared.getCodables(condition: Job.Properties.isHttpMessage == true, orderBy: [Job.Properties.orderId.asOrder(by: .ascending)], limit: limit)
    }
    
    func nextBatchSessionJobs(limit: Limit) -> [Job] {
        return MixinDatabase.shared.getCodables(condition: Job.Properties.isHttpMessage == false && Job.Properties.action == JobAction.SEND_SESSION_MESSAGE.rawValue, orderBy: [Job.Properties.orderId.asOrder(by: .ascending)], limit: limit)
    }
    
    func getCount() -> Int {
        return MixinDatabase.shared.getCount(on: Job.Properties.jobId.count(), fromTable: Job.tableName)
    }
    
    func removeJob(jobId: String) {
        MixinDatabase.shared.delete(table: Job.tableName, condition: Job.Properties.jobId == jobId)
    }
    
    func removeJobs(jobIds: [String]) {
        guard jobIds.count > 0 else {
            return
        }
        MixinDatabase.shared.delete(table: Job.tableName, condition: Job.Properties.jobId.in(jobIds))
    }
    
}
