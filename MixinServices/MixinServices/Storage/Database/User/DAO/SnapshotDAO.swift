import GRDB

public final class SnapshotDAO: UserDatabaseDAO {
    
    public static let shared = SnapshotDAO()
    
    private static let sqlQueryTable = """
    SELECT s.snapshot_id, s.type, s.asset_id, s.amount, s.opponent_id, s.transaction_hash, s.sender, s.receiver, s.memo, s.confirmations, s.trace_id, s.created_at, a.symbol, u.user_id, u.full_name, u.avatar_url, u.identity_number
    FROM snapshots s
    LEFT JOIN users u ON u.user_id = s.opponent_id
    LEFT JOIN assets a ON a.asset_id = s.asset_id
    """
    private static let sqlQueryById = "\(sqlQueryTable) WHERE s.snapshot_id = ?"
    private static let sqlQueryByTrace = "\(sqlQueryTable) WHERE s.trace_id = ?"
    
    public func saveSnapshot(snapshot: Snapshot) -> SnapshotItem? {
        var snapshotItem: SnapshotItem?
        db.write { (db) in
            try snapshot.save(db)
            db.afterNextTransactionCommit { (db) in
                snapshotItem = try? SnapshotItem.fetchOne(db,
                                                          sql: SnapshotDAO.sqlQueryById,
                                                          arguments: [snapshot.snapshotId],
                                                          adapter: nil)
            }
        }
        return snapshotItem
    }
    
    public func getSnapshots(assetId: String? = nil, below location: SnapshotItem? = nil, sort: Snapshot.Sort, filter: Snapshot.Filter, limit: Int) -> [SnapshotItem] {
        let additionalCondition: String?
        var additionalArguments: [String: String] = [:]
        if let assetId = assetId {
            additionalCondition = "snapshots.asset_id = :asset_id"
            additionalArguments["asset_id"] = assetId
        } else {
            additionalCondition = nil
        }
        return getSnapshotsAndRefreshCorrespondingAssetIfNeeded(below: location,
                                                                sort: sort,
                                                                filter: filter,
                                                                limit: limit,
                                                                additionalCondition: additionalCondition,
                                                                additionalArguments: additionalArguments)
    }
    
    public func getSnapshots(opponentId: String, below location: SnapshotItem? = nil, sort: Snapshot.Sort, filter: Snapshot.Filter, limit: Int) -> [SnapshotItem] {
        getSnapshotsAndRefreshCorrespondingAssetIfNeeded(below: location,
                                                         sort: sort,
                                                         filter: filter,
                                                         limit: limit,
                                                         additionalCondition: "snapshots.opponent_id = :opponent_id",
                                                         additionalArguments: ["opponent_id": opponentId])
    }
    
    public func getSnapshot(snapshotId: String) -> SnapshotItem? {
        db.select(with: SnapshotDAO.sqlQueryById, arguments: [snapshotId])
    }
    
    public func getSnapshot(traceId: String) -> SnapshotItem? {
        db.select(with: SnapshotDAO.sqlQueryByTrace, arguments: [traceId])
    }

    public func insertOrReplaceSnapshots(snapshots: [Snapshot], userInfo: [AnyHashable: Any]? = nil) {
        db.save(snapshots) { (db) in
            NotificationCenter.default.afterPostOnMain(name: .SnapshotDidChange, object: nil, userInfo: userInfo)
        }
    }
    
    public func replacePendingDeposits(assetId: String, pendingDeposits: [PendingDeposit]) {
        let snapshots = pendingDeposits.map({ $0.makeSnapshot(assetId: assetId )})
        db.write { (db) in
            let condition: SQLSpecificExpressible = Snapshot.column(of: .assetId) == assetId
                && Snapshot.column(of: .type) == SnapshotType.pendingDeposit.rawValue
            try Snapshot.filter(condition).deleteAll(db)
            for snapshot in snapshots {
                try snapshot.save(db)
            }
        }
    }
    
    public func removePendingDeposits(assetId: String, transactionHash: String) {
        let condition = Snapshot.column(of: .assetId) == assetId
            && Snapshot.column(of: .transactionHash) == transactionHash
            && Snapshot.column(of: .type) == SnapshotType.pendingDeposit.rawValue
        db.delete(Snapshot.self, where: condition)
    }
    
}

extension SnapshotDAO {
    
    private func getSnapshotsAndRefreshCorrespondingAssetIfNeeded(below location: SnapshotItem? = nil, sort: Snapshot.Sort, filter: Snapshot.Filter, limit: Int, additionalCondition: String?, additionalArguments: [String: String]) -> [SnapshotItem] {
        var sql = """
        SELECT snapshots.snapshot_id, snapshots.type, snapshots.asset_id, snapshots.amount,
                snapshots.opponent_id, snapshots.transaction_hash, snapshots.sender, snapshots.receiver,
                snapshots.memo, snapshots.confirmations, snapshots.trace_id, snapshots.created_at, assets.symbol,
                users.user_id, users.full_name, users.avatar_url, users.identity_number
        FROM (snapshots LEFT JOIN assets ON (snapshots.asset_id = assets.asset_id)
                        LEFT JOIN users ON (snapshots.opponent_id = users.user_id))
        """
        
        var conditions: [String] = []
        if let condition = additionalCondition {
            conditions.append(condition)
        }
        if let location = location {
            switch sort {
            case .createdAt:
                conditions.append("snapshots.created_at < :location_created_at")
            case .amount:
                let absAmount = "ABS(snapshots.amount)"
                let locationAbsAmount = "ABS(:location_amount)"
                let condition = "\(absAmount) < \(locationAbsAmount) OR (\(absAmount) = \(locationAbsAmount) AND snapshots.created_at < :location_created_at)"
                conditions.append(condition)
            }
        }
        if filter != .all {
            let types = filter.snapshotTypes.map(\.rawValue).joined(separator: "', '")
            conditions.append("snapshots.type IN('\(types)')")
        }
        if !conditions.isEmpty {
            sql += "\nWHERE (\(conditions.joined(separator: ") AND (")))"
        }
        
        switch sort {
        case .createdAt:
            sql += "\nORDER BY snapshots.created_at DESC"
        case .amount:
            sql += "\nORDER BY ABS(snapshots.amount) DESC, snapshots.created_at DESC"
        }
        
        sql += "\nLIMIT \(limit)"
        
        var arguments: [String: String] = [:]
        arguments["location_created_at"] = location?.createdAt
        arguments["location_amount"] = location?.amount
        for (key, value) in additionalArguments {
            arguments[key] = value
        }
        
        let snapshots: [SnapshotItem] = db.select(with: sql, arguments: StatementArguments(arguments))
        for snapshot in snapshots where snapshot.assetSymbol == nil {
            let job = RefreshAssetsJob(assetId: snapshot.assetId)
            ConcurrentJobQueue.shared.addJob(job: job)
        }
        return snapshots
    }

    private func refreshAssetIfNeeded(_ snapshot: SnapshotItem) {
        guard snapshot.assetSymbol == nil else {
            return
        }
        let job = RefreshAssetsJob(assetId: snapshot.assetId)
        ConcurrentJobQueue.shared.addJob(job: job)
    }
    
}
