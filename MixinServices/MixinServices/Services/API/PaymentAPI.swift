import MixinServices

public final class PaymentAPI: MixinAPI {
    
    private enum Path {
        static let transactions = "/transactions"
        static let transfers = "/transfers"
        static let payments = "/payments"
    }
    
    public static func payments(assetId: String, opponentId: String, amount: String, traceId: String) -> MixinAPI.Result<PaymentResponse> {
        let param: [String : Any] = ["asset_id": assetId, "opponent_id": opponentId, "amount": amount, "trace_id": traceId]
        return request(method: .post, path: Path.payments, parameters: param)
    }
    
    public static func payments(assetId: String, addressId: String, amount: String, traceId: String) -> MixinAPI.Result<PaymentResponse> {
        let param: [String : Any] = ["asset_id": assetId, "address_id": addressId, "amount": amount, "trace_id": traceId]
        return request(method: .post, path: Path.payments, parameters: param)
    }
    
    public static func payments(assetId: String, destination: String, tag: String, amount: String, traceId: String) -> MixinAPI.Result<PaymentResponse> {
        let param: [String : Any] = ["asset_id": assetId, "destination": destination, "amount": amount, "trace_id": traceId, "tag": tag]
        return request(method: .post, path: Path.payments, parameters: param)
    }
    
    public static func transactions(transactionRequest: RawTransactionRequest, pin: String, completion: @escaping (MixinAPI.Result<Snapshot>) -> Void) {
        var transactionRequest = transactionRequest
        PINEncryptor.encrypt(pin: pin, tipBody: {
            try TIPBody.createRawTransaction(assetID: transactionRequest.assetId,
                                             opponentKey: "",
                                             opponentReceivers: transactionRequest.opponentMultisig.receivers,
                                             opponentThreshold: transactionRequest.opponentMultisig.threshold,
                                             amount: transactionRequest.amount,
                                             traceID: transactionRequest.traceId,
                                             memo: transactionRequest.memo)
        }, onFailure: completion) { (encryptedPin) in
            transactionRequest.pin = encryptedPin
            request(method: .post, path: Path.transactions, parameters: transactionRequest, options: .disableRetryOnRequestSigningTimeout, completion: completion)
        }
    }
    
    public static func transfer(assetId: String, opponentId: String, amount: String, memo: String, pin: String, traceId: String, completion: @escaping (MixinAPI.Result<Snapshot>) -> Void) {
        let formattedAmount = AmountFormatter.formattedAmount(amount)
        PINEncryptor.encrypt(pin: pin, tipBody: {
            try TIPBody.transfer(assetID: assetId, oppositeUserID: opponentId, amount: formattedAmount, traceID: traceId, memo: memo)
        }, onFailure: completion) { (encryptedPin) in
            let param = ["asset_id": assetId, "opponent_id": opponentId, "amount": formattedAmount, "memo": memo, "pin_base64": encryptedPin, "trace_id": traceId]
            request(method: .post, path: Path.transfers, parameters: param, options: .disableRetryOnRequestSigningTimeout, completion: completion)
        }
    }
    
}
