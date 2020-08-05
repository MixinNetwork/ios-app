import WCDBSwift

public final class TraceDAO {

    public static let shared = TraceDAO()

    public func getTrace(assetId: String, amount: String, opponentId: String?, destination: String?, tag: String?, createdAt: String) -> Trace? {
        let condition: Condition
        if let opponentId = opponentId, !opponentId.isEmpty {
            condition = Trace.Properties.assetId == assetId
                && Trace.Properties.amount == amount
                && Trace.Properties.opponentId == opponentId
                && Trace.Properties.createdAt <= createdAt
        } else if let destination = destination, !destination.isEmpty {
            if let tag = tag, !tag.isEmpty {
                condition = Trace.Properties.assetId == assetId
                    && Trace.Properties.amount == amount
                    && Trace.Properties.destination == destination
                    && Trace.Properties.tag == tag
                    && Trace.Properties.createdAt <= createdAt
            } else {
                condition = Trace.Properties.assetId == assetId
                    && Trace.Properties.amount == amount
                    && Trace.Properties.destination == destination
                    && Trace.Properties.createdAt <= createdAt
            }
        } else {
            return nil
        }
        return MixinDatabase.shared.getCodable(condition: condition)
    }

    public func saveTrace(trace: Trace) {
        DispatchQueue.global().async {
            MixinDatabase.shared.insertOrReplace(objects: [trace])
        }
    }

}
