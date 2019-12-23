import WCDBSwift

public final class SnapshotDAO {
    
    static let shared = SnapshotDAO()
    
    private static let sqlQueryTable = """
    SELECT s.snapshot_id, s.type, s.asset_id, s.amount, s.opponent_id, s.transaction_hash, s.sender, s.receiver, s.memo, s.confirmations, s.trace_id, s.created_at, a.symbol, u.user_id, u.full_name, u.avatar_url, u.identity_number
    FROM snapshots s
    LEFT JOIN users u ON u.user_id = s.opponent_id
    LEFT JOIN assets a ON a.asset_id = s.asset_id
    """
    private static let sqlQueryById = "\(sqlQueryTable) WHERE s.snapshot_id = ?"
    private static let sqlQueryByTrace = "\(sqlQueryTable) WHERE s.trace_id = ?"
    
    private let createdAt = Snapshot.Properties.createdAt.in(table: Snapshot.tableName)
    
    func saveSnapshot(snapshot: Snapshot) -> SnapshotItem? {
        var snapshotItem: SnapshotItem?
        MixinDatabase.shared.transaction { (db) in
            try db.insertOrReplace(objects: snapshot, intoTable: Snapshot.tableName)
            snapshotItem = try db.prepareSelectSQL(on: SnapshotItem.Properties.all, sql: SnapshotDAO.sqlQueryById, values: [snapshot.snapshotId]).allObjects().first
        }
        return snapshotItem
    }
    
    func getSnapshots(assetId: String? = nil, below location: SnapshotItem? = nil, sort: Snapshot.Sort, filter: Snapshot.Filter, limit: Int) -> [SnapshotItem] {
        let amount = Snapshot.Properties.amount.in(table: Snapshot.tableName)
        return getSnapshotsAndRefreshCorrespondingAssetIfNeeded { (statement) -> (StatementSelect) in
            var stmt = statement
            var condition = Expression(booleanLiteral: true)
            if let assetId = assetId {
                condition = condition && Snapshot.Properties.assetId.in(table: Snapshot.tableName) == assetId
            }
            switch sort {
            case .createdAt:
                if let location = location {
                    condition = condition && createdAt < location.createdAt
                }
            case .amount:
                if let location = location {
                    let absAmount = amount.abs()
                    let locationAbsAmount = Expression(stringLiteral: location.amount).abs()
                    let isBelowLocation = absAmount < locationAbsAmount
                        || (absAmount == locationAbsAmount && createdAt < location.createdAt)
                    condition = condition && isBelowLocation
                }
            }
            
            if filter != .all {
                let types = filter.snapshotTypes.map({ $0.rawValue })
                let typeConstraint = Snapshot.Properties.type.in(table: Snapshot.tableName).in(types)
                condition = condition && typeConstraint
            }
            
            stmt.where(condition)
            switch sort {
            case .createdAt:
                stmt = stmt.order(by: createdAt.asOrder(by: .descending))
            case .amount:
                stmt = stmt.order(by: [amount.abs().asOrder(by: .descending), createdAt.asOrder(by: .descending)])
            }
            stmt = stmt.limit(limit)
            return stmt
        }
    }
    
    func getSnapshots(opponentId: String, below location: SnapshotItem? = nil, sort: Snapshot.Sort, filter: Snapshot.Filter, limit: Int) -> [SnapshotItem] {
        let amount = Snapshot.Properties.amount.in(table: Snapshot.tableName)
        return getSnapshotsAndRefreshCorrespondingAssetIfNeeded { (statement) -> (StatementSelect) in
            var stmt = statement
            var condition = Expression(booleanLiteral: true)
            condition = condition && Snapshot.Properties.opponentId.in(table: Snapshot.tableName) == opponentId
            switch sort {
            case .createdAt:
                if let location = location {
                    condition = condition && createdAt < location.createdAt
                }
            case .amount:
                if let location = location {
                    let absAmount = amount.abs()
                    let locationAbsAmount = Expression(stringLiteral: location.amount).abs()
                    let isBelowLocation = absAmount < locationAbsAmount
                        || (absAmount == locationAbsAmount && createdAt < location.createdAt)
                    condition = condition && isBelowLocation
                }
            }
            
            if filter != .all {
                let types = filter.snapshotTypes.map({ $0.rawValue })
                let typeConstraint = Snapshot.Properties.type.in(table: Snapshot.tableName).in(types)
                condition = condition && typeConstraint
            }
            
            stmt.where(condition)
            switch sort {
            case .createdAt:
                stmt = stmt.order(by: createdAt.asOrder(by: .descending))
            case .amount:
                stmt = stmt.order(by: [amount.abs().asOrder(by: .descending), createdAt.asOrder(by: .descending)])
            }
            stmt = stmt.limit(limit)
            return stmt
        }
    }
    
    func getSnapshot(snapshotId: String) -> SnapshotItem? {
        return MixinDatabase.shared.getCodables(on: SnapshotItem.Properties.all, sql: SnapshotDAO.sqlQueryById, values: [snapshotId]).first
    }

    func getSnapshot(traceId: String) -> SnapshotItem? {
        return MixinDatabase.shared.getCodables(on: SnapshotItem.Properties.all, sql: SnapshotDAO.sqlQueryByTrace, values: [traceId]).first
    }
    
    func insertOrReplaceSnapshots(snapshots: [Snapshot], userInfo: [AnyHashable: Any]? = nil) {
        MixinDatabase.shared.insertOrReplace(objects: snapshots)
        NotificationCenter.default.afterPostOnMain(name: .SnapshotDidChange, object: nil, userInfo: userInfo)
    }
    
    func replacePendingDeposits(assetId: String, pendingDeposits: [PendingDeposit]) {
        let snapshots = pendingDeposits.map({ $0.makeSnapshot(assetId: assetId )})
        MixinDatabase.shared.transaction { (db) in
            try db.delete(fromTable: Snapshot.tableName,
                          where: Snapshot.Properties.assetId == assetId && Snapshot.Properties.type == SnapshotType.pendingDeposit.rawValue)
            if snapshots.count > 0 {
                try db.insertOrReplace(objects: snapshots, intoTable: Snapshot.tableName)
            }
        }
    }
    
    func removePendingDeposits(assetId: String, transactionHash: String) {
        let condition = Snapshot.Properties.assetId == assetId
            && Snapshot.Properties.transactionHash == transactionHash
            && Snapshot.Properties.type == SnapshotType.pendingDeposit.rawValue
        MixinDatabase.shared.delete(table: Snapshot.tableName, condition: condition)
    }
    
}

extension SnapshotDAO {
    
    private func getSnapshotsAndRefreshCorrespondingAssetIfNeeded(prepare: (StatementSelect) -> (StatementSelect)) -> [SnapshotItem] {
        let columns = Snapshot.Properties.all.map({ $0.in(table: Snapshot.tableName) })
            + [Asset.Properties.symbol.in(table: Asset.tableName),
               User.Properties.userId.in(table: User.tableName),
               User.Properties.fullName.in(table: User.tableName),
               User.Properties.avatarUrl.in(table: User.tableName),
               User.Properties.identityNumber.in(table: User.tableName)]
        let joinedTable = JoinClause(with: Snapshot.tableName)
            .join(Asset.tableName, with: .left)
            .on(Snapshot.Properties.assetId.in(table: Snapshot.tableName)
                == Asset.Properties.assetId.in(table: Asset.tableName))
            .join(User.tableName, with: .left)
            .on(Snapshot.Properties.opponentId.in(table: Snapshot.tableName)
                == User.Properties.userId.in(table: User.tableName))
        var stmt = StatementSelect().select(columns).from(joinedTable)
        stmt = prepare(stmt)
        let snapshots: [SnapshotItem] = MixinDatabase.shared.getCodables(statement: stmt)
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
