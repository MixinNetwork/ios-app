import WCDBSwift

final class SnapshotDAO {
    
    static let shared = SnapshotDAO()
    
    private let createdAt = Snapshot.Properties.createdAt.in(table: Snapshot.tableName)
    
    func getSnapshots(assetId: String? = nil, below location: SnapshotItem? = nil, sort: Snapshot.Sort, limit: Int) -> [SnapshotItem] {
        let amount = Snapshot.Properties.amount.in(table: Snapshot.tableName)
        return getSnapshotsAndRefreshCorrespondingAssetIfNeeded { (statement) -> (StatementSelect) in
            var stmt = statement
            if let assetId = assetId {
                stmt = stmt.where(Snapshot.Properties.assetId == assetId)
            }
            switch sort {
            case .createdAt:
                if let location = location {
                    stmt = stmt.where(createdAt < location.createdAt)
                }
                stmt = stmt.order(by: createdAt.asOrder(by: .descending))
            case .amount:
                if let location = location {
                    stmt = stmt.where(amount < location.amount && createdAt < location.createdAt)
                }
                stmt = stmt.order(by: [amount.asOrder(by: .descending), createdAt.asOrder(by: .descending)])
            }
            stmt = stmt.limit(limit)
            return stmt
        }
    }
    
    func getSnapshots(opponentId: String) -> [SnapshotItem] {
        return getSnapshotsAndRefreshCorrespondingAssetIfNeeded { (stmt) -> (StatementSelect) in
            stmt.where(Snapshot.Properties.opponentId.in(table: Snapshot.tableName) == opponentId)
                .order(by: createdAt.asOrder(by: .descending))
        }
    }
    
    func getSnapshot(snapshotId: String) -> SnapshotItem? {
        return getSnapshotsAndRefreshCorrespondingAssetIfNeeded(prepare: { (stmt) -> (StatementSelect) in
            stmt.where(Snapshot.Properties.snapshotId.in(table: Snapshot.tableName) == snapshotId)
                .order(by: createdAt.asOrder(by: .descending))
                .limit(1)
        }).first
    }
    
    func insertOrReplaceSnapshots(snapshots: [Snapshot], userInfo: [AnyHashable: Any]? = nil) {
        MixinDatabase.shared.insertOrReplace(objects: snapshots)
        NotificationCenter.default.afterPostOnMain(name: .SnapshotDidChange, object: nil, userInfo: userInfo)
    }
    
    func replacePendingDeposits(assetId: String, pendingDeposits: [PendingDeposit]) {
        MixinDatabase.shared.transaction { (db) in
            try db.delete(fromTable: Snapshot.tableName,
                          where: Snapshot.Properties.assetId == assetId && Snapshot.Properties.type == SnapshotType.pendingDeposit.rawValue)
            if pendingDeposits.count > 0 {
                try db.insert(objects: pendingDeposits.map({ $0.makeSnapshot(assetId: assetId )}), intoTable: Snapshot.tableName)
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
    
    private static let columns = Snapshot.Properties.all.map({ $0.in(table: Snapshot.tableName) })
        + [Asset.Properties.symbol.in(table: Asset.tableName),
           User.Properties.userId.in(table: User.tableName),
           User.Properties.fullName.in(table: User.tableName),
           User.Properties.avatarUrl.in(table: User.tableName),
           User.Properties.identityNumber.in(table: User.tableName)]
    private static let joinClause = JoinClause(with: Snapshot.tableName)
        .join(Asset.tableName, with: .left)
        .on(Snapshot.Properties.assetId.in(table: Snapshot.tableName)
            == Asset.Properties.assetId.in(table: Asset.tableName))
        .join(User.tableName, with: .left)
        .on(Snapshot.Properties.opponentId.in(table: Snapshot.tableName)
            == User.Properties.userId.in(table: User.tableName))
    
    private func getSnapshotsAndRefreshCorrespondingAssetIfNeeded(prepare: (StatementSelect) -> (StatementSelect)) -> [SnapshotItem] {
        var items = [SnapshotItem]()
        var stmt = StatementSelect().select(SnapshotDAO.columns).from(SnapshotDAO.joinClause)
        stmt = prepare(stmt)
        return MixinDatabase.shared.getCodables(callback: { (db) in
            let cs = try db.prepare(stmt)
            while try cs.step() {
                var i = -1
                var autoIncrementIndex: Int {
                    i += 1
                    return i
                }
                let item = SnapshotItem(snapshotId: cs.value(atIndex: autoIncrementIndex, of: String.self) ?? "",
                                        type: cs.value(atIndex: autoIncrementIndex, of: String.self) ?? "",
                                        assetId: cs.value(atIndex: autoIncrementIndex, of: String.self) ?? "",
                                        amount: cs.value(atIndex: autoIncrementIndex, of: String.self) ?? "",
                                        opponentId: cs.value(atIndex: autoIncrementIndex, of: String.self),
                                        transactionHash: cs.value(atIndex: autoIncrementIndex, of: String.self),
                                        sender: cs.value(atIndex: autoIncrementIndex, of: String.self),
                                        receiver: cs.value(atIndex: autoIncrementIndex, of: String.self),
                                        memo: cs.value(atIndex: autoIncrementIndex, of: String.self),
                                        confirmations: cs.value(atIndex: autoIncrementIndex, of: Int.self),
                                        createdAt: cs.value(atIndex: autoIncrementIndex, of: String.self) ?? "",
                                        assetSymbol: cs.value(atIndex: autoIncrementIndex, of: String.self),
                                        opponentUserId: cs.value(atIndex: autoIncrementIndex, of: String.self),
                                        opponentUserFullName: cs.value(atIndex: autoIncrementIndex, of: String.self),
                                        opponentUserAvatarUrl: cs.value(atIndex: autoIncrementIndex, of: String.self),
                                        opponentUserIdentityNumber: cs.value(atIndex: autoIncrementIndex, of: String.self))
                refreshAssetIfNeeded(item)
                items.append(item)
            }
            return items
        })
    }
    
    private func refreshAssetIfNeeded(_ snapshot: SnapshotItem) {
        guard snapshot.assetSymbol == nil else {
            return
        }
        let job = RefreshAssetsJob(assetId: snapshot.assetId)
        ConcurrentJobQueue.shared.addJob(job: job)
    }
    
}
