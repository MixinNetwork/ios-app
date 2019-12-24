import Foundation
import WCDBSwift

public final class JobDAO {
    
    public static let shared = JobDAO()
    
    internal func nextJob() -> Job? {
        return MixinDatabase.shared.getCodables(condition: Job.Properties.isHttpMessage == false, orderBy: [Job.Properties.priority.asOrder(by: .descending), Job.Properties.orderId.asOrder(by: .ascending)], limit: 1).first
    }
    
    public func clearSessionJob() {
        MixinDatabase.shared.delete(table: Job.tableName, condition: Job.Properties.isHttpMessage == false && (Job.Properties.action == JobAction.SEND_SESSION_MESSAGE.rawValue || Job.Properties.action == JobAction.SEND_SESSION_MESSAGES.rawValue))
    }
    
    internal func nextBatchHttpJobs(limit: Limit) -> [Job] {
        return MixinDatabase.shared.getCodables(condition: Job.Properties.isHttpMessage == true, orderBy: [Job.Properties.orderId.asOrder(by: .ascending)], limit: limit)
    }
    
    internal func nextBatchSessionJobs(limit: Limit) -> [Job] {
        return MixinDatabase.shared.getCodables(condition: Job.Properties.isHttpMessage == false && Job.Properties.action == JobAction.SEND_SESSION_MESSAGE.rawValue, orderBy: [Job.Properties.orderId.asOrder(by: .ascending)], limit: limit)
    }
    
    internal func getCount() -> Int {
        return MixinDatabase.shared.getCount(on: Job.Properties.jobId.count(), fromTable: Job.tableName)
    }
    
    internal func removeJob(jobId: String) {
        MixinDatabase.shared.delete(table: Job.tableName, condition: Job.Properties.jobId == jobId)
    }
    
    internal func removeJobs(jobIds: [String]) {
        guard jobIds.count > 0 else {
            return
        }
        MixinDatabase.shared.delete(table: Job.tableName, condition: Job.Properties.jobId.in(jobIds))
    }
    
}
