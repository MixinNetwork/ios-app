import MixinServices

final class SnapshotAPI: BaseAPI {

    private enum url {
        static func snapshot(snapshotId: String) -> String {
            return "snapshots/\(snapshotId)"
        }
        static func snapshot(traceId: String) -> String {
            return "transfers/trace/\(traceId)"
        }
    }
    static let shared = SnapshotAPI()

    func snapshot(snapshotId: String) -> APIResult<Snapshot> {
        return request(method: .get, url: url.snapshot(snapshotId: snapshotId))
    }

    func snapshot(traceId: String) -> APIResult<Snapshot> {
        return request(method: .get, url: url.snapshot(traceId: traceId))
    }

}
