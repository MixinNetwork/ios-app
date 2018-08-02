import Foundation

class WalletUserDefault {

    static let shared = WalletUserDefault()

    private var keyDefalutTransferAssetId: String {
        return "defalut_transfer_asset_id_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyLastInputPINSuccess: String {
        return "last_input_pin_success_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyCheckPINInterval: String {
        return "check_pin_interval_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyHiddenAssets: String {
        return "hidden_assets_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyWithdrawalAddresses: String {
        return "withdrawal_addresses_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyIsBiometricPay: String {
        return "is_biometric_pay_\(AccountAPI.shared.accountIdentityNumber)"
    }

    let session = UserDefaults(suiteName: SuiteName.wallet)!
    let checkMaxInterval: Double = 60 * 60 * 24
    let checkMinInterval: Double = 60 * 10

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
        guard AccountAPI.shared.account?.has_pin ?? false, session.object(forKey: keyCheckPINInterval) == nil  else {
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

    var lastWithdrawalAddress: [String: String] {
        get {
            return session.dictionary(forKey: keyWithdrawalAddresses) as? [String: String] ?? [:]
        }
        set {
            session.set(newValue, forKey: keyWithdrawalAddresses)
            NotificationCenter.default.afterPostOnMain(name: .DefaultAddressDidChange)
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
}
