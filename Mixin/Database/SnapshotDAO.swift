import WCDBSwift

final class SnapshotDAO {

    static let shared = SnapshotDAO()

    private static let sqlQueryByAssetId = """
    SELECT s.snapshot_id, s.type, s.asset_id, a.symbol as assetSymbol, s.amount, s.opponent_id, s.transaction_hash, s.sender, s.created_at, u.full_name as opponentUserFullName, s.receiver, s.confirmations, s.memo, u.avatar_url as opponent_avatar_url FROM snapshots s
    LEFT JOIN users u ON s.opponent_id = u.user_id
    LEFT JOIN assets a ON s.asset_id = a.asset_id
    WHERE s.asset_id = ?
    ORDER BY s.created_at DESC
    """
    private static let sqlQueryBySnapshotId = """
    SELECT s.snapshot_id, s.type, s.asset_id, a.symbol as assetSymbol, s.amount, s.opponent_id, s.transaction_hash, s.sender, s.created_at, u.full_name as opponentUserFullName, s.receiver, s.confirmations, s.memo FROM snapshots s
    LEFT JOIN users u ON s.opponent_id = u.user_id
    LEFT JOIN assets a ON s.asset_id = a.asset_id
    WHERE s.snapshot_id = ?
    ORDER BY s.created_at DESC
    """
    private static let sqlQueryByOpponentId = """
    SELECT s.snapshot_id, s.type, s.asset_id, a.symbol as assetSymbol, s.amount, s.opponent_id, s.transaction_hash, s.sender, s.created_at, u.full_name as opponentUserFullName, s.receiver, s.confirmations, s.memo FROM snapshots s
    LEFT JOIN users u ON s.opponent_id = u.user_id
    LEFT JOIN assets a ON s.asset_id = a.asset_id
    WHERE s.opponent_id = ?
    ORDER BY s.created_at DESC
    """
    private static let sqlQuery = """
    SELECT s.snapshot_id, s.type, s.asset_id, a.symbol as assetSymbol, s.amount, s.opponent_id, s.transaction_hash, s.sender, s.created_at, u.full_name as opponentUserFullName, s.receiver, s.confirmations, s.memo FROM snapshots s
    LEFT JOIN users u ON s.opponent_id = u.user_id
    LEFT JOIN assets a ON s.asset_id = a.asset_id
    ORDER BY s.created_at DESC
    LIMIT ? OFFSET ?
    """

    func snapshots(offset: Int, limit: Int) -> [SnapshotItem] {
        return checkSnapshots(MixinDatabase.shared.getCodables(sql: SnapshotDAO.sqlQuery, values: [limit, offset], inTransaction: false))
    }

    func replaceSnapshot(snapshot: Snapshot) {
        updateSnapshots(snapshots: [snapshot])
    }

    func insertOrUpdateSnapshots(snapshots: [Snapshot]) {
        MixinDatabase.shared.insertOrReplace(objects: snapshots)
    }

    func updateSnapshots(snapshots: [Snapshot]) {
        MixinDatabase.shared.insertOrReplace(objects: snapshots)
        NotificationCenter.default.afterPostOnMain(name: .SnapshotDidChange, object: nil)
    }
    
    func getSnapshots(assetId: String) -> [SnapshotItem] {
        return checkSnapshots(MixinDatabase.shared.getCodables(sql: SnapshotDAO.sqlQueryByAssetId, values: [assetId], inTransaction: false))
    }
    
    func getSnapshots(opponentId: String) -> [SnapshotItem] {
        return checkSnapshots(MixinDatabase.shared.getCodables(sql: SnapshotDAO.sqlQueryByOpponentId, values: [opponentId], inTransaction: false))
    }

    func getSnapshot(snapshotId: String) -> SnapshotItem? {
        return MixinDatabase.shared.getCodables(sql: SnapshotDAO.sqlQueryBySnapshotId, values: [snapshotId], inTransaction: false).first
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
        MixinDatabase.shared.delete(table: Snapshot.tableName, condition: Snapshot.Properties.assetId == assetId && Snapshot.Properties.transactionHash == transactionHash
            && Snapshot.Properties.type == SnapshotType.pendingDeposit.rawValue)
    }

    private func checkSnapshots(_ snapshots: [SnapshotItem]) -> [SnapshotItem] {
        let assetIds: [String] = snapshots
            .filter({ $0.assetSymbol == nil })
            .compactMap({ $0.assetId })
        if assetIds.count > 0 {
            for assetId in assetIds {
                ConcurrentJobQueue.shared.addJob(job: RefreshAssetsJob(assetId: assetId))
            }
        }
        return snapshots
    }
    
}

