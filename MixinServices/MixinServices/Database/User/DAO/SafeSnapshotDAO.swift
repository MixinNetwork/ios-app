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
        
        case before(offset: SafeSnapshotItem, includesOffset: Bool)
        case after(offset: SafeSnapshotItem, includesOffset: Bool)
        
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
        offset: Offset? = nil,
        filter: SafeSnapshot.Filter,
        order: SafeSnapshot.Order,
        limit: Int
    ) -> [SafeSnapshotItem] {
        var query = GRDB.SQL(sql: Self.querySQL)
        
        var conditions: [GRDB.SQL] = []
        if !filter.tokens.isEmpty {
            conditions.append("s.asset_id IN \(filter.tokens.map(\.assetID))")
        }
        if !filter.users.isEmpty {
            conditions.append("s.opponent_id IN \(filter.users.map(\.userId))")
        }
        for address in filter.addresses {
            let keyword = "%\(address.destination.sqlEscaped)%"
            let condition: GRDB.SQL = "(s.deposit LIKE \(keyword) OR s.withdrawal LIKE \(keyword))"
            conditions.append(condition)
        }
        if let type = filter.type {
            switch type {
            case .deposit:
                conditions.append("s.deposit IS NOT NULL")
            case .withdrawal:
                conditions.append("s.withdrawal IS NOT NULL")
            case .transfer:
                conditions.append("s.deposit IS NULL")
                conditions.append("s.withdrawal IS NULL")
            }
        }
        
        if let offset {
            switch (order, offset) {
            case let (.oldest, .after(offset, includesOffset)), let (.newest, .before(offset, includesOffset)):
                if includesOffset {
                    conditions.append("s.created_at >= \(offset.createdAt)")
                } else {
                    conditions.append("s.created_at > \(offset.createdAt)")
                }
            case let (.oldest, .before(offset, includesOffset)), let (.newest, .after(offset, includesOffset)):
                if includesOffset {
                    conditions.append("s.created_at <= \(offset.createdAt)")
                } else {
                    conditions.append("s.created_at < \(offset.createdAt)")
                }
            case let (.mostValuable, .after(offset, includesOffset)):
                let offsetValue = offset.decimalAmount * (offset.decimalTokenUSDPrice ?? 0)
                let lesserValue: GRDB.SQL = "ABS(s.amount * IFNULL(t.price_usd, 0)) < ABS(\(offsetValue))"
                let equalValue: GRDB.SQL = "ABS(s.amount * IFNULL(t.price_usd, 0)) = ABS(\(offsetValue))"
                if includesOffset {
                    conditions.append("(\(lesserValue) OR (\(equalValue) AND s.created_at <= \(offset.createdAt)))")
                } else {
                    conditions.append("(\(lesserValue) OR (\(equalValue) AND s.created_at < \(offset.createdAt)))")
                }
            case let (.mostValuable, .before(offset, includesOffset)):
                let offsetValue = offset.decimalAmount * (offset.decimalTokenUSDPrice ?? 0)
                let greaterValue: GRDB.SQL = "ABS(s.amount * IFNULL(t.price_usd, 0)) > ABS(\(offsetValue))"
                let equalValue: GRDB.SQL = "ABS(s.amount * IFNULL(t.price_usd, 0)) = ABS(\(offsetValue))"
                if includesOffset {
                    conditions.append("(\(greaterValue) OR (\(equalValue) AND s.created_at >= \(offset.createdAt)))")
                } else {
                    conditions.append("(\(greaterValue) OR (\(equalValue) AND s.created_at > \(offset.createdAt)))")
                }
            case let (.biggestAmount, .after(offset, includesOffset)):
                let lesserAmount: GRDB.SQL = "ABS(s.amount) < ABS(\(offset.amount))"
                let equalAmount: GRDB.SQL = "ABS(s.amount) = ABS(\(offset.amount))"
                if includesOffset {
                    conditions.append("(\(lesserAmount) OR (\(equalAmount) AND s.created_at <= \(offset.createdAt)))")
                } else {
                    conditions.append("(\(lesserAmount) OR (\(equalAmount) AND s.created_at < \(offset.createdAt)))")
                }
            case let (.biggestAmount, .before(offset, includesOffset)):
                let greaterAmount: GRDB.SQL = "ABS(s.amount) > ABS(\(offset.amount))"
                let equalAmount: GRDB.SQL = "ABS(s.amount) = ABS(\(offset.amount))"
                if includesOffset {
                    conditions.append("(\(greaterAmount) OR (\(equalAmount) AND s.created_at >= \(offset.createdAt)))")
                } else {
                    conditions.append("(\(greaterAmount) OR (\(equalAmount) AND s.created_at > \(offset.createdAt)))")
                }
            }
        }
        if !conditions.isEmpty {
            query.append(literal: "WHERE \(conditions.joined(operator: .and))\n")
        }
        
        switch order {
        case .newest:
            query.append(sql: "ORDER BY s.created_at DESC")
        case .oldest:
            query.append(sql: "ORDER BY s.created_at ASC")
        case .mostValuable:
            query.append(sql: "ORDER BY ABS(s.amount * t.price_usd) DESC, s.created_at DESC")
        case .biggestAmount:
            query.append(sql: "ORDER BY ABS(s.amount) DESC, s.created_at DESC")
        }
        
        query.append(literal: "\nLIMIT \(limit)")
        
        return db.select(with: query)
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
