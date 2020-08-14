import MixinServices

final class SnapshotAPI: BaseAPI {

    private enum url {
        static func snapshot(snapshotId: String) -> String {
            return "snapshots/\(snapshotId)"
        }
        static func trace(traceId: String) -> String {
            return "snapshots/trace/\(traceId)"
        }
        static let payments = "payments"
    }
    static let shared = SnapshotAPI()

    func snapshot(snapshotId: String) -> BaseAPI.Result<Snapshot> {
        return request(method: .get, url: url.snapshot(snapshotId: snapshotId))
    }

    func trace(traceId: String) -> BaseAPI.Result<Snapshot> {
        return request(method: .get, url: url.trace(traceId: traceId))
    }

    func payments(traceId: String, assetId: String, opponentId: String, amount: String, completion: @escaping (BaseAPI.Result<TraceResponse>) -> Void) {
        let param: [String : Any] = ["asset_id": assetId, "opponent_id": opponentId, "amount": amount, "trace_id": traceId]
        request(method: .post, url: url.payments, parameters: param, completion: completion)
    }

    func payments(traceId: String, assetId: String, addressId: String, amount: String, completion: @escaping (BaseAPI.Result<TraceResponse>) -> Void) {
        let param: [String : Any] = ["asset_id": assetId, "address_id": addressId, "amount": amount, "trace_id": traceId]
        request(method: .post, url: url.payments, parameters: param, completion: completion)
    }


}
