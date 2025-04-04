import Foundation

internal class WalletUserDefault {

    static let shared = WalletUserDefault()

    private var keyDefalutTransferAssetId: String {
        return "defalut_transfer_asset_id_\(myIdentityNumber)"
    }
    private var keyLastInputPINSuccess: String {
        return "last_input_pin_success_\(myIdentityNumber)"
    }
    private var keyCheckPINInterval: String {
        return "check_pin_interval_\(myIdentityNumber)"
    }
    private var keyHiddenAssets: String {
        return "hidden_assets_\(myIdentityNumber)"
    }
    private var keyIsBiometricPay: String {
        return "is_biometric_pay_\(myIdentityNumber)"
    }
    private var keyPINInterval: String {
        return "is_pin_interval_\(myIdentityNumber)"
    }
    private var keyAllTransactionOffset: String {
        return "all_transaction_offset_\(myIdentityNumber)"
    }
    private var keyAssetTransactionOffset: String {
        return "asset_transaction_offset_\(myIdentityNumber)"
    }
    private var keyWithdrawalTip: String {
        return "asset_withdrawal_tip_\(myIdentityNumber)"
    }
    private var keyCurrencyCode: String {
        return "currency_code_\(myIdentityNumber)"
    }
    
    let session = UserDefaults(suiteName: SuiteName.wallet)!
    let checkMaxInterval: Double = 60 * 60 * 24
    let checkMinInterval: Double = 60 * 10
    let pinMinInterval: Double = 60 * 15
    let pinDefaultInterval: Double = 60 * 120

    var firstWithdrawalTip: [String] {
        get {
            return session.stringArray(forKey: keyWithdrawalTip) ?? []
        }
        set {
            session.set(newValue, forKey: keyWithdrawalTip)
        }
    }

    var defalutTransferAssetId: String? {
        get {
            return session.string(forKey: keyDefalutTransferAssetId)
        }
        set {
            session.set(newValue, forKey: keyDefalutTransferAssetId)
        }
    }

    var checkPinInterval: Double {
        get {
            let interval = session.double(forKey: keyCheckPINInterval)
            return interval < checkMinInterval ? checkMinInterval : interval
        }
        set {
            if newValue > checkMaxInterval {
                session.set(checkMaxInterval, forKey: keyCheckPINInterval)
            } else {
                session.set(newValue, forKey: keyCheckPINInterval)
            }
        }
    }

    func initPinInterval() {
        guard LoginManager.shared.account?.hasPIN ?? false, session.object(forKey: keyCheckPINInterval) == nil  else {
            return
        }

        checkPinInterval = checkMaxInterval
    }

    var lastInputPinTime: Double {
        get {
            return session.double(forKey: keyLastInputPINSuccess)
        }
        set {
            session.set(newValue, forKey: keyLastInputPINSuccess)
        }
    }

    var hiddenAssets: [String: Any] {
        get {
            return session.dictionary(forKey: keyHiddenAssets) ?? [:]
        }
        set {
            session.set(newValue, forKey: keyHiddenAssets)
        }
    }

    var isBiometricPay: Bool {
        get {
            return session.bool(forKey: keyIsBiometricPay)
        }
        set {
            session.set(newValue, forKey: keyIsBiometricPay)
        }
    }

    var pinInterval: Double {
        get {
            let interval = session.double(forKey: keyPINInterval)
            return interval < pinMinInterval ? pinDefaultInterval : interval
        }
        set {
            session.set(newValue, forKey: keyPINInterval)
        }
    }

    func clearBiometricPay() {
        session.removeObject(forKey: keyIsBiometricPay)
    }
    
    var allTransactionOffset: String? {
        get {
            return session.string(forKey: keyAllTransactionOffset)
        }
        set {
            session.set(newValue, forKey: keyAllTransactionOffset)
        }
    }
    
    // Key is asset id, value is offset
    var assetTransactionOffset: [String: String] {
        get {
            return (session.dictionary(forKey: keyAssetTransactionOffset) as? [String: String]) ?? [:]
        }
        set {
            session.set(newValue, forKey: keyAssetTransactionOffset)
        }
    }
    
    var currencyCode: String? {
        get {
            return session.string(forKey: keyCurrencyCode)
        }
    }

}
