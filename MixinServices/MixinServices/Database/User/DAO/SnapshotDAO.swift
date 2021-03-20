import GRDB

public final class SnapshotDAO: UserDatabaseDAO {
    
    public static let shared = SnapshotDAO()
    public static let snapshotDidChangeNotification = NSNotification.Name("one.mixin.services.SnapshotDAO.snapshotDidChange")
    
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
                                                          arguments: [snapshot.snapshotId])
            }
        }
        return snapshotItem
    }
    
    public func getSnapshots(assetId: String? = nil, below location: SnapshotItem? = nil, sort: Snapshot.Sort, filter: Snapshot.Filter, limit: Int) -> [SnapshotItem] {
        if let assetId = assetId {
            return getSnapshotsAndRefreshCorrespondingAssetIfNeeded(below: location,
                                                                    sort: sort,
                                                                    filter: filter,
                                                                    limit: limit,
                                                                    additionalConditions: ["s.asset_id = :asset_id"],
                                                                    additionalArguments: ["asset_id": assetId])
        } else {
            return getSnapshotsAndRefreshCorrespondingAssetIfNeeded(below: location,
                                                                    sort: sort,
                                                                    filter: filter,
                                                                    limit: limit,
                                                                    additionalConditions: [],
                                                                    additionalArguments: [:])
        }
    }
    
    public func getSnapshots(opponentId: String, below location: SnapshotItem? = nil, sort: Snapshot.Sort, filter: Snapshot.Filter, limit: Int) -> [SnapshotItem] {
        getSnapshotsAndRefreshCorrespondingAssetIfNeeded(below: location,
                                                         sort: sort,
                                                         filter: filter,
                                                         limit: limit,
                                                         additionalConditions: ["s.opponent_id = :opponent_id"],
                                                         additionalArguments: ["opponent_id": opponentId])
    }
    
    public func getSnapshot(snapshotId: String) -> SnapshotItem? {
        db.select(with: SnapshotDAO.sqlQueryById, arguments: [snapshotId])
    }
    
    public func getSnapshot(traceId: String) -> SnapshotItem? {
        db.select(with: SnapshotDAO.sqlQueryByTrace, arguments: [traceId])
    }
    
    public func saveSnapshots(snapshots: [Snapshot], userInfo: [AnyHashable: Any]? = nil) {
        db.save(snapshots) { (db) in
            NotificationCenter.default.post(onMainThread: SnapshotDAO.snapshotDidChangeNotification, object: self, userInfo: userInfo)
        }
    }
    
    @discardableResult
    public func replacePendingDeposits(assetId: String, pendingDeposits: [PendingDeposit], snapshotId: String? = nil) -> SnapshotItem? {
        guard !pendingDeposits.isEmpty else {
            return nil
        }
        var snapshotItem: SnapshotItem?
        let hashList = pendingDeposits.map{ $0.transactionHash }
        
        db.write { (db) in
            let request = Snapshot
                .select(Snapshot.column(of: .transactionHash))
                .filter(Snapshot.column(of: .assetId) == assetId
                            && Snapshot.column(of: .type) == SnapshotType.deposit.rawValue
                            && hashList.contains(Snapshot.column(of: .transactionHash)))
            let transactionHashList = try String.fetchAll(db, request)
            let snapshots: [Snapshot]
            if transactionHashList.isEmpty {
                snapshots = pendingDeposits.map{ $0.makeSnapshot(assetId: assetId )}
            } else {
                snapshots = pendingDeposits
                    .filter { !transactionHashList.contains($0.transactionHash) }
                    .map{ $0.makeSnapshot(assetId: assetId )}
            }
                        
            let condition: SQLSpecificExpressible = Snapshot.column(of: .assetId) == assetId
                && Snapshot.column(of: .type) == SnapshotType.pendingDeposit.rawValue
            try Snapshot.filter(condition).deleteAll(db)
            try snapshots.save(db)
            
            if let snapshotId = snapshotId {
                db.afterNextTransactionCommit { (db) in
                    snapshotItem = try? SnapshotItem.fetchOne(db,
                                                              sql: SnapshotDAO.sqlQueryById,
                                                              arguments: [snapshotId])
                }
            }
        }
        return snapshotItem
    }
    
    public func removePendingDeposits(assetId: String, transactionHash: String) {
        let condition = Snapshot.column(of: .assetId) == assetId
            && Snapshot.column(of: .transactionHash) == transactionHash
            && Snapshot.column(of: .type) == SnapshotType.pendingDeposit.rawValue
        db.delete(Snapshot.self, where: condition)
    }
    
}

extension SnapshotDAO {
    
    private func getSnapshotsAndRefreshCorrespondingAssetIfNeeded(
        below location: SnapshotItem? = nil,
        sort: Snapshot.Sort,
        filter: Snapshot.Filter,
        limit: Int,
        additionalConditions: [String],
        additionalArguments: [String: String]
    ) -> [SnapshotItem] {
        var sql = """
        SELECT s.snapshot_id, s.type, s.asset_id, s.amount,
                s.opponent_id, s.transaction_hash, s.sender, s.receiver,
                s.memo, s.confirmations, s.trace_id, s.created_at, a.symbol,
                u.user_id, u.full_name, u.avatar_url, u.identity_number
        FROM snapshots s
        LEFT JOIN assets a ON s.asset_id = a.asset_id
        LEFT JOIN users u ON s.opponent_id = u.user_id
        
        """
        
        var conditions = additionalConditions
        if let location = location {
            switch sort {
            case .createdAt:
                conditions.append("s.created_at < :location_created_at")
            case .amount:
                let absAmount = "ABS(s.amount)"
                let locationAbsAmount = "ABS(:location_amount)"
                conditions.append("(\(absAmount) < \(locationAbsAmount) OR (\(absAmount) = \(locationAbsAmount) AND s.created_at < :location_created_at))")
            }
        }
        if filter != .all {
            let types = filter.snapshotTypes.map(\.rawValue).joined(separator: "', '")
            conditions.append("s.type IN('\(types)')")
        }
        if !conditions.isEmpty {
            sql += "WHERE " + conditions.joined(separator: " AND ")
        }
        
        switch sort {
        case .createdAt:
            sql += "\nORDER BY s.created_at DESC"
        case .amount:
            sql += "\nORDER BY ABS(s.amount) DESC, s.created_at DESC"
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
    
}
