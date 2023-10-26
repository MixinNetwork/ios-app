import GRDB

public final class SafeSnapshotDAO: UserDatabaseDAO {
    
    public static let shared = SafeSnapshotDAO()
    
    public static let snapshotDidChangeNotification = NSNotification.Name("one.mixin.services.SafeSnapshotDAO.snapshotDidChange")
    
    public func snapshot(id: String) -> SafeSnapshot? {
        db.select(where: SafeSnapshot.column(of: .id) == id)
    }
    
    public func save(snapshot: SafeSnapshot) {
        db.save(snapshot)
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
        var sql = """
        SELECT s.*, a.symbol AS \(SafeSnapshotItem.JoinedQueryCodingKeys.assetSymbol.rawValue),
            u.user_id AS \(SafeSnapshotItem.JoinedQueryCodingKeys.opponentUserID.rawValue),
            u.full_name AS \(SafeSnapshotItem.JoinedQueryCodingKeys.opponentFullname.rawValue),
            u.avatar_url AS \(SafeSnapshotItem.JoinedQueryCodingKeys.opponentAvatarURL.rawValue)
        FROM safe_snapshots s
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
        arguments["location_created_at"] = location?.createdAt.toUTCString()
        arguments["location_amount"] = location?.amount
        for (key, value) in additionalArguments {
            arguments[key] = value
        }
        
        let snapshots: [SafeSnapshotItem] = db.select(with: sql, arguments: StatementArguments(arguments))
        for snapshot in snapshots where snapshot.assetSymbol == nil {
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
    
}
