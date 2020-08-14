import MixinServices

final class PaymentAPI: BaseAPI {

    private enum url {
        static let transactions = "transactions"
        static let transfers = "transfers"

    }
    static let shared = PaymentAPI()

    func transactions(transactionRequest: RawTransactionRequest, pin: String, completion: @escaping (BaseAPI.Result<Snapshot>) -> Void) {
        var transactionRequest = transactionRequest
        KeyUtil.aesEncrypt(pin: pin, completion: completion) { [weak self](encryptedPin) in
            transactionRequest.pin = encryptedPin
            self?.request(method: .post, url: url.transactions, parameters: transactionRequest.toParameters(), encoding: EncodableParameterEncoding<RawTransactionRequest>(), completion: completion)
        }
    }

    func transfer(assetId: String, opponentId: String, amount: String, memo: String, pin: String, traceId: String, completion: @escaping (BaseAPI.Result<Snapshot>) -> Void) {
        KeyUtil.aesEncrypt(pin: pin, completion: completion) { [weak self](encryptedPin) in
            let param: [String : Any] = ["asset_id": assetId, "opponent_id": opponentId, "amount": amount, "memo": memo, "pin": encryptedPin, "trace_id": traceId]
            self?.request(method: .post, url: url.transfers, parameters: param, completion: completion)
        }
    }

}
