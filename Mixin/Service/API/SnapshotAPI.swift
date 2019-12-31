import MixinServices

class SnapshotAPI: BaseAPI {

    private enum url {
        static func snapshots(opponentId: String) -> String {
            return "mutual_snapshots/\(opponentId)"
        }

        static func snapshot(snapshotId: String) -> String {
            return "snapshots/\(snapshotId)"
        }
        static func snapshot(traceId: String) -> String {
            return "transfers/trace/\(traceId)"
        }
    }
    static let shared = SnapshotAPI()

    func snapshots(opponentId: String) -> APIResult<[Snapshot]> {
        return request(method: .get, url: url.snapshots(opponentId: opponentId))
    }

    func snapshot(snapshotId: String) -> APIResult<Snapshot> {
        return request(method: .get, url: url.snapshot(snapshotId: snapshotId))
    }

    func snapshot(traceId: String) -> APIResult<Snapshot> {
        return request(method: .get, url: url.snapshot(traceId: traceId))
    }

}
