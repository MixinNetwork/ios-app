import MixinServices

public final class SnapshotAPI: MixinAPI {
    
    private enum Path {
        static func snapshot(snapshotId: String) -> String {
            return "/snapshots/\(snapshotId)"
        }
        static func trace(traceId: String) -> String {
            return "/snapshots/trace/\(traceId)"
        }
    }
    
    public static func snapshot(snapshotId: String) -> MixinAPI.Result<Snapshot> {
        return request(method: .get, path: Path.snapshot(snapshotId: snapshotId))
    }
    
    public static func snapshot(snapshotId: String, completion: @escaping (MixinAPI.Result<Snapshot>) -> Void) {
        request(method: .get, path: Path.snapshot(snapshotId: snapshotId), completion: completion)
    }
    
    public static func trace(traceId: String) -> MixinAPI.Result<Snapshot> {
        return request(method: .get, path: Path.trace(traceId: traceId))
    }
    
}
