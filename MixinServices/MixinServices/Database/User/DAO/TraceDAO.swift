import GRDB

public final class TraceDAO: UserDatabaseDAO {
    
    public static let shared = TraceDAO()
    
    public func getTrace(assetId: String, amount: String, opponentId: String?, destination: String?, tag: String?, createdAt: String) -> Trace? {
        let condition: SQLSpecificExpressible
        if let opponentId = opponentId, !opponentId.isEmpty {
            condition = Trace.column(of: .assetId) == assetId
                && Trace.column(of: .amount) == amount
                && Trace.column(of: .opponentId) == opponentId
                && Trace.column(of: .createdAt) >= createdAt
        } else if let destination = destination, !destination.isEmpty {
            if let tag = tag, !tag.isEmpty {
                condition = Trace.column(of: .assetId) == assetId
                    && Trace.column(of: .amount) == amount
                    && Trace.column(of: .destination) == destination
                    && Trace.column(of: .tag) == tag
                    && Trace.column(of: .createdAt) >= createdAt
            } else {
                condition = Trace.column(of: .assetId) == assetId
                    && Trace.column(of: .amount) == amount
                    && Trace.column(of: .destination) == destination
                    && Trace.column(of: .createdAt) >= createdAt
            }
        } else {
            return nil
        }
        return db.select(where: condition, order: [Trace.column(of: .createdAt).desc])
    }
    
    public func getTrace(traceId: String) -> Trace? {
        db.select(where: Trace.column(of: .traceId) == traceId)
    }
    
    public func deleteTrace(traceId: String) {
        db.delete(Trace.self, where: Trace.column(of: .traceId) == traceId)
    }
    
    public func saveTrace(trace: Trace?) {
        guard let trace = trace else {
            return
        }
        DispatchQueue.global().async {
            self.db.write { (db) in
                try Trace
                    .filter(Trace.column(of: .createdAt) < Date().within6Hours().toUTCString())
                    .deleteAll(db)
                try trace.save(db)
            }
        }
    }
    
    public func updateSnapshot(traceId: String, snapshotId: String) {
        db.update(Trace.self,
                  assignments: [Trace.column(of: .snapshotId).set(to: snapshotId)],
                  where: Trace.column(of: .traceId) == traceId)
    }
    
}
