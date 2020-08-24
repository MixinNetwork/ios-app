import WCDBSwift

public final class TraceDAO {

    public static let shared = TraceDAO()

    public func getTrace(assetId: String, amount: String, opponentId: String?, destination: String?, tag: String?, createdAt: String) -> Trace? {
        let condition: Condition
        if let opponentId = opponentId, !opponentId.isEmpty {
            condition = Trace.Properties.assetId == assetId
                && Trace.Properties.amount == amount
                && Trace.Properties.opponentId == opponentId
                && Trace.Properties.createdAt >= createdAt
        } else if let destination = destination, !destination.isEmpty {
            if let tag = tag, !tag.isEmpty {
                condition = Trace.Properties.assetId == assetId
                    && Trace.Properties.amount == amount
                    && Trace.Properties.destination == destination
                    && Trace.Properties.tag == tag
                    && Trace.Properties.createdAt >= createdAt
            } else {
                condition = Trace.Properties.assetId == assetId
                    && Trace.Properties.amount == amount
                    && Trace.Properties.destination == destination
                    && Trace.Properties.createdAt >= createdAt
            }
        } else {
            return nil
        }
        return MixinDatabase.shared.getCodable(condition: condition, orderBy: [Trace.Properties.createdAt.asOrder(by: .descending)])
    }

    public func getTrace(traceId: String) -> Trace? {
        return MixinDatabase.shared.getCodable(condition: Trace.Properties.traceId == traceId)
    }

    public func deleteTrace(traceId: String) {
        MixinDatabase.shared.delete(table: Trace.tableName, condition: Trace.Properties.traceId == traceId)
    }

    public func saveTrace(trace: Trace?) {
        guard let trace = trace else {
            return
        }
        DispatchQueue.global().async {
            MixinDatabase.shared.delete(table: Trace.tableName, condition: Trace.Properties.createdAt < Date().within6Hours().toUTCString())
            MixinDatabase.shared.insertOrReplace(objects: [trace])
        }
    }

    public func updateSnapshot(traceId: String, snapshotId: String) {
        MixinDatabase.shared.update(maps: [(Trace.Properties.snapshotId, snapshotId)], tableName: Trace.tableName, condition: Trace.Properties.traceId == traceId)
    }

}
