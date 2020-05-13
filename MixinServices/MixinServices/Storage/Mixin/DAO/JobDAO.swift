import Foundation
import WCDBSwift

public final class JobDAO {
    
    public static let shared = JobDAO()
    
    internal func nextJob(category: JobCategory) -> Job? {
        return MixinDatabase.shared.getCodables(condition: Job.Properties.category == category.rawValue, orderBy: [Job.Properties.priority.asOrder(by: .descending), Job.Properties.orderId.asOrder(by: .ascending)], limit: 1).first
    }
    
    public func clearSessionJob() {
        MixinDatabase.shared.delete(table: Job.tableName, condition: Job.Properties.category == JobCategory.WebSocket.rawValue && Job.Properties.action.in(JobAction.SEND_SESSION_MESSAGE.rawValue, JobAction.SEND_SESSION_MESSAGES.rawValue))
    }

    public func nextJobs(category: JobCategory, action: JobAction, limit: Limit? = nil) -> [String: String] {
        return MixinDatabase.shared.getDictionary(key: Job.Properties.jobId.asColumnResult(), value: Job.Properties.messageId.asColumnResult(), tableName: Job.tableName, condition: Job.Properties.category == category.rawValue && Job.Properties.action == action.rawValue, orderBy: [Job.Properties.orderId.asOrder(by: .ascending)], limit: limit)
    }

    internal func nextBatchJobs(category: JobCategory, limit: Limit) -> [Job] {
        return MixinDatabase.shared.getCodables(condition: Job.Properties.category == category.rawValue, orderBy: [Job.Properties.orderId.asOrder(by: .ascending)], limit: limit)
    }

    public func nextBatchJobs(category: JobCategory, action: JobAction, limit: Limit?) -> [Job] {
        return MixinDatabase.shared.getCodables(condition: Job.Properties.category == category.rawValue && Job.Properties.action == action.rawValue, orderBy: [Job.Properties.orderId.asOrder(by: .ascending)], limit: limit)
    }

    public func getCount(category: JobCategory) -> Int {
        return MixinDatabase.shared.getCount(on: Job.Properties.jobId.count(), fromTable: Job.tableName, condition: Job.Properties.category == category.rawValue)
    }

    internal func getCount() -> Int {
        return MixinDatabase.shared.getCount(on: Job.Properties.jobId.count(), fromTable: Job.tableName)
    }
    
    public func removeJob(jobId: String) {
        MixinDatabase.shared.delete(table: Job.tableName, condition: Job.Properties.jobId == jobId)
    }
    
    internal func removeJobs(jobIds: [String]) {
        guard jobIds.count > 0 else {
            return
        }
        MixinDatabase.shared.delete(table: Job.tableName, condition: Job.Properties.jobId.in(jobIds))
    }
    
}
