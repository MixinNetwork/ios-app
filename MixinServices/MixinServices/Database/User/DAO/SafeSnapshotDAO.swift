import GRDB

public final class SafeSnapshotDAO: UserDatabaseDAO {
    
    public static let shared = SafeSnapshotDAO()
    
    public static let snapshotDidChangeNotification = NSNotification.Name("one.mixin.services.SafeSnapshotDAO.snapshotDidChange")
    
    private static let querySQL = """
        SELECT s.*, t.symbol AS \(SafeSnapshotItem.JoinedQueryCodingKeys.tokenSymbol.rawValue),
            u.user_id AS \(SafeSnapshotItem.JoinedQueryCodingKeys.opponentUserID.rawValue),
            u.full_name AS \(SafeSnapshotItem.JoinedQueryCodingKeys.opponentFullname.rawValue),
            u.avatar_url AS \(SafeSnapshotItem.JoinedQueryCodingKeys.opponentAvatarURL.rawValue)
        FROM safe_snapshots s
            LEFT JOIN tokens t ON s.asset_id = t.asset_id
            LEFT JOIN users u ON s.opponent_id = u.user_id
    
    """
    private static let queryWithIDSQL = querySQL + "WHERE s.snapshot_id = ?"
    
    public func snapshotItem(id: String) -> SafeSnapshotItem? {
        db.select(with: Self.queryWithIDSQL, arguments: [id])
    }
    
    public func save(snapshot: SafeSnapshot) {
        db.save(snapshot)
    }
    
    public func saveAndFetch(snapshot: SafeSnapshot) -> SafeSnapshotItem? {
        try? db.writeAndReturnError { db in
            try snapshot.save(db)
            return try SafeSnapshotItem.fetchOne(db, sql: Self.queryWithIDSQL, arguments: [snapshot.id])
        }
    }
    
    public func snapshots(
        assetId: String? = nil,
        below location: SafeSnapshot? = nil,
        sort: Snapshot.Sort,
        limit: Int
    ) -> [SafeSnapshotItem] {
        if let assetId = assetId {
            return getSnapshotsAndRefreshCorrespondingAssetIfNeeded(below: location,
                                                                    sort: sort,
                                                                    limit: limit,
                                                                    additionalConditions: ["s.asset_id = :asset_id"],
                                                                    additionalArguments: ["asset_id": assetId])
        } else {
            return getSnapshotsAndRefreshCorrespondingAssetIfNeeded(below: location,
                                                                    sort: sort,
                                                                    limit: limit,
                                                                    additionalConditions: [],
                                                                    additionalArguments: [:])
        }
    }
    
    public func snapshots(
        opponentID: String,
        below location: SafeSnapshot? = nil,
        sort: Snapshot.Sort,
        limit: Int
    ) -> [SafeSnapshotItem] {
        getSnapshotsAndRefreshCorrespondingAssetIfNeeded(below: location,
                                                         sort: sort,
                                                         limit: limit,
                                                         additionalConditions: ["s.opponent_id = :opponent_id"],
                                                         additionalArguments: ["opponent_id": opponentID])
    }
    
    private func getSnapshotsAndRefreshCorrespondingAssetIfNeeded(
        below location: SafeSnapshot? = nil,
        sort: Snapshot.Sort,
        limit: Int,
        additionalConditions: [String],
        additionalArguments: [String: String]
    ) -> [SafeSnapshotItem] {
        var sql = Self.querySQL
        
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
        
        let snapshots: [SafeSnapshotItem] = db.select(with: sql, arguments: StatementArguments(arguments))
        for snapshot in snapshots where snapshot.tokenSymbol == nil {
            let job = RefreshTokenJob(assetID: snapshot.assetID)
            ConcurrentJobQueue.shared.addJob(job: job)
        }
        return snapshots
    }
    
    public func save(snapshots: [SafeSnapshot], userInfo: [AnyHashable: Any]? = nil) {
        db.save(snapshots) { (db) in
            NotificationCenter.default.post(onMainThread: SafeSnapshotDAO.snapshotDidChangeNotification, object: self, userInfo: userInfo)
        }
    }
    
    public func saveSnapshots(with assetID: String, pendingDeposits: [SafePendingDeposit]) {
        guard !pendingDeposits.isEmpty else {
            return
        }
        let ids = pendingDeposits.map(\.id).joined(separator: "','")
        db.write { (db) in
            let finishedDepositIDs: [String] = try String.fetchAll(db, sql: """
                SELECT snapshot_id FROM safe_snapshots WHERE asset_id = ? AND type != ? AND id IN ('\(ids)')
            """, arguments: [assetID, SafeSnapshot.SnapshotType.pending.rawValue])
            let snapshots: [SafeSnapshot] = pendingDeposits.compactMap { deposit in
                if finishedDepositIDs.contains(deposit.id) {
                    return nil
                } else {
                    return SafeSnapshot(assetID: assetID, pendingDeposit: deposit)
                }
            }
            try snapshots.save(db)
        }
    }
    
}
