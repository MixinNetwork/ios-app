import WCDBSwift

final class SnapshotDAO {

    static let shared = SnapshotDAO()

    private static let sqlQuery = """
    SELECT s.snapshot_id, s.type, s.asset_id, s.amount, s.counter_user_id, s.transaction_hash, s.sender, s.created_at, u.full_name as counterUserFullName, s.receiver, s.memo FROM snapshots s
    LEFT JOIN users u ON s.counter_user_id = u.user_id
    WHERE s.asset_id = ?
    ORDER BY s.created_at DESC
    """
    private static let sqlQueryById = """
    SELECT s.snapshot_id, s.type, s.asset_id, s.amount, s.counter_user_id, s.transaction_hash, s.sender, s.created_at, u.full_name as counterUserFullName, s.receiver, s.memo FROM snapshots s
    LEFT JOIN users u ON s.counter_user_id = u.user_id
    WHERE s.snapshot_id = ?
    ORDER BY s.created_at DESC
    """

    func replaceSnapshot(snapshot: Snapshot) {
        updateSnapshots(assetId: snapshot.assetId, snapshots: [snapshot])
    }

    func updateSnapshots(assetId: String, snapshots: [Snapshot]) {
        MixinDatabase.shared.insertOrReplace(objects: snapshots)
        NotificationCenter.default.afterPostOnMain(name: .SnapshotDidChange, object: assetId)
    }

    func getSnapshots(assetId: String) -> [SnapshotItem] {
        return MixinDatabase.shared.getCodables(sql: SnapshotDAO.sqlQuery, values: [assetId], inTransaction: false)
    }

    func getSnapshot(snapshotId: String) -> SnapshotItem? {
        return MixinDatabase.shared.getCodables(sql: SnapshotDAO.sqlQueryById, values: [snapshotId], inTransaction: false).first
    }

}

