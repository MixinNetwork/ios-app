import MixinServices

final class SnapshotAPI: BaseAPI {

    private enum url {
        static func snapshot(snapshotId: String) -> String {
            return "snapshots/\(snapshotId)"
        }
        static func trace(traceId: String) -> String {
            return "snapshots/trace/\(traceId)"
        }
    }
    static let shared = SnapshotAPI()

    func snapshot(snapshotId: String) -> BaseAPI.Result<Snapshot> {
        return request(method: .get, url: url.snapshot(snapshotId: snapshotId))
    }

    func trace(traceId: String) -> BaseAPI.Result<Snapshot> {
        return request(method: .get, url: url.trace(traceId: traceId))
    }

}
