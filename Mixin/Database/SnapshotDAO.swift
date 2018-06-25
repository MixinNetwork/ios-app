import WCDBSwift

final class SnapshotDAO {

    static let shared = SnapshotDAO()

    private static let sqlQueryByAssetId = """
    SELECT s.snapshot_id, s.type, s.asset_id, a.symbol as assetSymbol, s.amount, s.opponent_id, s.transaction_hash, s.sender, s.created_at, u.full_name as opponentUserFullName, s.receiver, s.memo FROM snapshots s
    LEFT JOIN users u ON s.opponent_id = u.user_id
    INNER JOIN assets a ON s.asset_id = a.asset_id
    WHERE s.asset_id = ?
    ORDER BY s.created_at DESC
    """
    private static let sqlQueryBySnapshotId = """
    SELECT s.snapshot_id, s.type, s.asset_id, a.symbol as assetSymbol, s.amount, s.opponent_id, s.transaction_hash, s.sender, s.created_at, u.full_name as opponentUserFullName, s.receiver, s.memo FROM snapshots s
    LEFT JOIN users u ON s.opponent_id = u.user_id
    INNER JOIN assets a ON s.asset_id = a.asset_id
    WHERE s.snapshot_id = ?
    ORDER BY s.created_at DESC
    """
    private static let sqlQuery = """
    SELECT s.snapshot_id, s.type, s.asset_id, a.symbol as assetSymbol, s.amount, s.opponent_id, s.transaction_hash, s.sender, s.created_at, u.full_name as opponentUserFullName, s.receiver, s.memo FROM snapshots s
    LEFT JOIN users u ON s.opponent_id = u.user_id
    INNER JOIN assets a ON s.asset_id = a.asset_id
    ORDER BY s.created_at DESC
    LIMIT ? OFFSET ?
    """

    func snapshots(offset: Int, limit: Int) -> [SnapshotItem] {
        return MixinDatabase.shared.getCodables(sql: SnapshotDAO.sqlQuery, values: [limit, offset], inTransaction: false)
    }

    func replaceSnapshot(snapshot: Snapshot) {
        updateSnapshots(assetId: snapshot.assetId, snapshots: [snapshot])
    }

    func insertOrUpdateSnapshots(snapshots: [Snapshot]) {
        MixinDatabase.shared.insertOrReplace(objects: snapshots)
    }

    func updateSnapshots(assetId: String, snapshots: [Snapshot]) {
        MixinDatabase.shared.insertOrReplace(objects: snapshots)
        NotificationCenter.default.afterPostOnMain(name: .SnapshotDidChange, object: assetId)
    }

    func getSnapshots(assetId: String) -> [SnapshotItem] {
        return MixinDatabase.shared.getCodables(sql: SnapshotDAO.sqlQueryByAssetId, values: [assetId], inTransaction: false)
    }

    func getSnapshot(snapshotId: String) -> SnapshotItem? {
        return MixinDatabase.shared.getCodables(sql: SnapshotDAO.sqlQueryBySnapshotId, values: [snapshotId], inTransaction: false).first
    }

}

