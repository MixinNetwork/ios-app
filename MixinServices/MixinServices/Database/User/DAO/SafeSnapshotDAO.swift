import GRDB

public final class SafeSnapshotDAO: UserDatabaseDAO {
    
    public static let shared = SafeSnapshotDAO()
    
    public static let snapshotDidSaveNotification = Notification.Name("one.mixin.services.SafeSnapshotDAO.SnapshotDidSave")
    public static let snapshotsUserInfoKey = "s"
    
    private static let querySQL = """
        SELECT s.*, t.symbol AS \(SafeSnapshotItem.JoinedQueryCodingKeys.tokenSymbol.rawValue),
            u.user_id AS \(SafeSnapshotItem.JoinedQueryCodingKeys.opponentUserID.rawValue),
            u.full_name AS \(SafeSnapshotItem.JoinedQueryCodingKeys.opponentFullname.rawValue),
            u.avatar_url AS \(SafeSnapshotItem.JoinedQueryCodingKeys.opponentAvatarURL.rawValue),
            ii.content_type AS \(SafeSnapshotItem.JoinedQueryCodingKeys.inscriptionContentType.rawValue),
            ii.content_url AS \(SafeSnapshotItem.JoinedQueryCodingKeys.inscriptionContentURL.rawValue),
            ic.icon_url AS \(SafeSnapshotItem.JoinedQueryCodingKeys.inscriptionCollectionIconURL.rawValue)
        FROM safe_snapshots s
            LEFT JOIN tokens t ON s.asset_id = t.asset_id
            LEFT JOIN users u ON s.opponent_id = u.user_id
            LEFT JOIN inscription_items ii ON s.inscription_hash = ii.inscription_hash
            LEFT JOIN inscription_collections ic ON ii.collection_hash = ic.collection_hash
        
    """
    private static let queryWithIDSQL = querySQL + "WHERE s.snapshot_id = ?"
    
}

extension SafeSnapshotDAO {
    
    public enum Offset: CustomDebugStringConvertible {
        
        case before(offset: SafeSnapshot, includesOffset: Bool)
        case after(offset: SafeSnapshot, includesOffset: Bool)
        
        public var debugDescription: String {
            switch self {
            case .before(let offset, let includesOffset):
                "<Offset before: \(offset), include: \(includesOffset)>"
            case .after(let offset, let includesOffset):
                "<Offset after: \(offset), include: \(includesOffset)>"
            }
        }
        
    }
    
    public func snapshotItem(id: String) -> SafeSnapshotItem? {
        db.select(with: Self.queryWithIDSQL, arguments: [id])
    }
    
    public func safeSnapshots(limit: Int, after snapshotId: String?) -> [SafeSnapshot] {
        var sql = "SELECT * FROM safe_snapshots"
        if let snapshotId {
            sql += " WHERE ROWID > IFNULL((SELECT ROWID FROM safe_snapshots WHERE snapshot_id = '\(snapshotId)'), 0)"
        }
        sql += " ORDER BY ROWID LIMIT ?"
        return db.select(with: sql, arguments: [limit])
    }
    
    public func safeSnapshotsCount() -> Int {
        let count: Int? = db.select(with: "SELECT COUNT(*) FROM safe_snapshots")
        return count ?? 0
    }
    
    public func inscriptionHash(snapshotID id: String) -> String? {
        db.select(with: "SELECT inscription_hash FROM safe_snapshots WHERE snapshot_id=?", arguments: [id])
    }
    
    public func snapshots(
        assetId: String? = nil,
        offset: Offset? = nil,
        sort: Snapshot.Sort,
        limit: Int
    ) -> [SafeSnapshotItem] {
        let (conditions, arguments) = if let assetId {
            (["s.asset_id = :asset_id"], ["asset_id": assetId])
        } else {
            ([], [:])
        }
        return getSnapshotsAndRefreshCorrespondingAssetIfNeeded(offset: offset,
                                                                sort: sort,
                                                                limit: limit,
                                                                additionalConditions: conditions,
                                                                additionalArguments: arguments)
    }
    
    public func snapshots(
        opponentID: String,
        offset: Offset? = nil,
        sort: Snapshot.Sort,
        limit: Int
    ) -> [SafeSnapshotItem] {
        getSnapshotsAndRefreshCorrespondingAssetIfNeeded(offset: offset,
                                                         sort: sort,
                                                         limit: limit,
                                                         additionalConditions: ["s.opponent_id = :opponent_id"],
                                                         additionalArguments: ["opponent_id": opponentID])
    }
    
    public func snapshots(
        assetID: String,
        address: String,
        offset: Offset? = nil,
        sort: Snapshot.Sort,
        limit: Int
    ) -> [SafeSnapshotItem] {
        let conditions = [
            "s.asset_id = :asset_id",
            "(s.deposit LIKE :address OR s.withdrawal LIKE :address)",
        ]
        let arguments = [
            "asset_id": assetID,
            "address": "%\(address)%",
        ]
        return getSnapshotsAndRefreshCorrespondingAssetIfNeeded(offset: offset,
                                                                sort: sort,
                                                                limit: limit,
                                                                additionalConditions: conditions,
                                                                additionalArguments: arguments)
    }
    
    private func getSnapshotsAndRefreshCorrespondingAssetIfNeeded(
        offset: Offset? = nil,
        sort: Snapshot.Sort,
        limit: Int,
        additionalConditions: [String],
        additionalArguments: [String: String]
    ) -> [SafeSnapshotItem] {
        var sql = Self.querySQL
        
        var conditions = additionalConditions
        var arguments = additionalArguments
        
        switch offset {
        case let .after(offset, includesOffset):
            switch sort {
            case .createdAt:
                if includesOffset {
                    conditions.append("s.created_at <= :offset_created_at")
                } else {
                    conditions.append("s.created_at < :offset_created_at")
                }
                arguments["offset_created_at"] = offset.createdAt
            case .amount:
                let amount = "ABS(s.amount)"
                let offsetAmount = "ABS(:offset_amount)"
                if includesOffset {
                    conditions.append("(\(amount) < \(offsetAmount) OR (\(amount) = \(offsetAmount) AND s.created_at <= :offset_created_at))")
                } else {
                    conditions.append("(\(amount) < \(offsetAmount) OR (\(amount) = \(offsetAmount) AND s.created_at < :offset_created_at))")
                }
                arguments["offset_amount"] = offset.amount
                arguments["offset_created_at"] = offset.createdAt
            }
        case let .before(offset, includesOffset):
            switch sort {
            case .createdAt:
                if includesOffset {
                    conditions.append("s.created_at >= :offset_created_at")
                } else {
                    conditions.append("s.created_at > :offset_created_at")
                }
                arguments["offset_created_at"] = offset.createdAt
            case .amount:
                let amount = "ABS(s.amount)"
                let offsetAmount = "ABS(:offset_amount)"
                if includesOffset {
                    conditions.append("(\(amount) > \(offsetAmount) OR (\(amount) = \(offsetAmount) AND s.created_at >= :offset_created_at))")
                } else {
                    conditions.append("(\(amount) > \(offsetAmount) OR (\(amount) = \(offsetAmount) AND s.created_at > :offset_created_at))")
                }
                arguments["offset_amount"] = offset.amount
                arguments["offset_created_at"] = offset.createdAt
            }
        case .none:
            break
        }
        if !conditions.isEmpty {
            sql += "WHERE " + conditions.joined(separator: " AND ")
        }
        
        switch sort {
        case .createdAt:
            switch offset {
            case .after, .none:
                sql += "\nORDER BY s.created_at DESC"
            case .before:
                sql += "\nORDER BY s.created_at ASC"
            }
        case .amount:
            switch offset {
            case .after, .none:
                sql += "\nORDER BY ABS(s.amount) DESC, s.created_at DESC"
            case .before:
                sql += "\nORDER BY ABS(s.amount) ASC, s.created_at ASC"
            }
        }
        
        sql += "\nLIMIT \(limit)"
        
        let snapshots: [SafeSnapshotItem] = db.select(with: sql, arguments: StatementArguments(arguments))
        for snapshot in snapshots where snapshot.tokenSymbol == nil {
            let job = RefreshTokenJob(assetID: snapshot.assetID)
            ConcurrentJobQueue.shared.addJob(job: job)
        }
        return snapshots
    }
    
}

extension SafeSnapshotDAO {
    
    public func saveWithoutNotification(snapshot: SafeSnapshot) {
        db.write { db in
            try snapshot.save(db)
        }
    }
    
    public func save(
        snapshot: SafeSnapshot,
        savedItem handler: @escaping ((SafeSnapshotItem?) -> Void)
    ) {
        save(snapshot: snapshot) { db in
            let item = try SafeSnapshotItem.fetchOne(db, sql: Self.queryWithIDSQL, arguments: [snapshot.id])
            handler(item)
        }
    }
    
    public func save(
        snapshot: SafeSnapshot,
        alongsideTransaction change: ((GRDB.Database) throws -> Void)? = nil
    ) {
        db.write { db in
            try save(snapshot: snapshot, db: db)
            try change?(db)
        }
    }
    
    public func save(snapshot: SafeSnapshot, db: GRDB.Database) throws {
        try snapshot.save(db)
        db.afterNextTransaction { _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.snapshotDidSaveNotification,
                                                object: self,
                                                userInfo: [Self.snapshotsUserInfoKey: [snapshot]])
            }
        }
    }
    
    public func save(
        snapshots: [SafeSnapshot],
        alongsideTransaction change: ((GRDB.Database) throws -> Void)
    ) {
        db.write { db in
            try snapshots.save(db)
            try change(db)
            db.afterNextTransaction { _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Self.snapshotDidSaveNotification,
                                                    object: self,
                                                    userInfo: [Self.snapshotsUserInfoKey: snapshots])
                }
            }
        }
    }
    
}

extension SafeSnapshotDAO {
    
    public func replaceAllPendingSnapshots(with pendingDeposits: [SafePendingDeposit]) {
        db.write { db in
            var changesCount = 0
            
            try db.execute(sql: "DELETE FROM safe_snapshots WHERE type = ?",
                           arguments: [SafeSnapshot.SnapshotType.pending.rawValue])
            changesCount += db.changesCount

            let snapshots = pendingDeposits.map(SafeSnapshot.init(pendingDeposit:))
            try snapshots.save(db)
            changesCount += db.changesCount
            
            if changesCount > 0 {
                db.afterNextTransaction { _ in
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: Self.snapshotDidSaveNotification, 
                                                        object: self,
                                                        userInfo: [Self.snapshotsUserInfoKey: snapshots])
                    }
                }
            }
        }
    }
    
    public func replacePendingSnapshots(assetID: String, pendingDeposits: [SafePendingDeposit]) {
        db.write { (db) in
            var changesCount = 0
            
            try db.execute(sql: "DELETE FROM safe_snapshots WHERE asset_id = ? AND type = ?",
                           arguments: [assetID, SafeSnapshot.SnapshotType.pending.rawValue])
            changesCount += db.changesCount
            
            let snapshots = pendingDeposits.map(SafeSnapshot.init(pendingDeposit:))
            try snapshots.save(db)
            changesCount += db.changesCount
            
            if changesCount > 0 {
                db.afterNextTransaction { _ in
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: Self.snapshotDidSaveNotification,
                                                        object: self,
                                                        userInfo: [Self.snapshotsUserInfoKey: snapshots])
                    }
                }
            }
        }
    }
    
    public func deletePendingSnapshots(depositHash: String, db: GRDB.Database) throws {
        let sql = "DELETE FROM safe_snapshots WHERE type = 'pending' AND deposit LIKE ?"
        try db.execute(sql: sql, arguments: ["%\(depositHash)%"])
    }
    
}
