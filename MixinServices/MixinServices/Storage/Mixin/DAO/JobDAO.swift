import Foundation
import GRDB

public final class JobDAO: UserDatabaseDAO {
    
    public static let shared = JobDAO()
    
    internal func nextJob(category: JobCategory) -> Job? {
        let orderings = [
            Job.column(of: .priority).desc,
            Job.column(of: .orderId).asc
        ]
        return db.select(where: Job.column(of: .category) == category.rawValue, order: orderings)
    }
    
    public func clearSessionJob() {
        let condition = Job.column(of: .category) == JobCategory.WebSocket.rawValue
            && [JobAction.SEND_SESSION_MESSAGE.rawValue, JobAction.SEND_SESSION_MESSAGES.rawValue].contains(Job.column(of: .action))
        db.delete(Job.self, where: condition)
    }
    
    public func nextJobs(category: JobCategory, action: JobAction, limit: Int? = nil) -> [String: String] {
        db.select(keyColumn: Job.column(of: .jobId),
                  valueColumn: Job.column(of: .messageId),
                  from: Job.self,
                  where: Job.column(of: .category) == category.rawValue && Job.column(of: .action) == action.rawValue,
                  order: [Job.column(of: .orderId).asc],
                  limit: limit)
    }
    
    internal func nextBatchJobs(category: JobCategory, limit: Int) -> [Job] {
        db.select(where: Job.column(of: .category) == category.rawValue,
                  order: [Job.column(of: .orderId).asc],
                  limit: limit)
    }
    
    public func nextBatchJobs(category: JobCategory, action: JobAction, limit: Int?) -> [Job] {
        let condition = Job.column(of: .category) == category.rawValue
            && Job.column(of: .action) == action.rawValue
        return db.select(where: condition,
                         order: [Job.column(of: .orderId).asc],
                         limit: limit)
    }
    
    public func getCount(category: JobCategory) -> Int {
        db.count(in: Job.self, where: Job.column(of: .category) == category.rawValue)
    }
    
    internal func getCount() -> Int {
        db.count(in: Job.self)
    }
    
    public func removeJob(jobId: String) {
        db.delete(Job.self, where: Job.column(of: .jobId) == jobId)
    }
    
    internal func removeJobs(jobIds: [String]) {
        guard !jobIds.isEmpty else {
            return
        }
        db.delete(Job.self, where: jobIds.contains(Job.column(of: .jobId)))
    }
    
}
