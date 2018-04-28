import Foundation

class WalletUserDefault {

    static let shared = WalletUserDefault()

    private var keyDefalutTransferAssetId: String {
        return "defalut_transfer_asset_id_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyLastInputPINSuccess: String {
        return "last_input_pin_success_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyHiddenAssets: String {
        return "hidden_assets_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyWithdrawalAddresses: String {
        return "withdrawal_addresses_\(AccountAPI.shared.accountIdentityNumber)"
    }

    let session = UserDefaults(suiteName: SuiteName.wallet)

    var defalutTransferAssetId: String? {
        get {
            return session?.string(forKey: keyDefalutTransferAssetId)
        }
        set {
            session?.set(newValue, forKey: keyDefalutTransferAssetId)
        }
    }

    var lastInputPinTime: Double {
        get {
            return session?.double(forKey: keyLastInputPINSuccess) ?? 0
        }
        set {
            session?.set(newValue, forKey: keyLastInputPINSuccess)
        }
    }

    var hiddenAssets: [String: Any] {
        get {
            return session?.dictionary(forKey: keyHiddenAssets) ?? [:]
        }
        set {
            session?.set(newValue, forKey: keyHiddenAssets)
        }
    }

    var lastWithdrawalAddress: [String: String] {
        get {
            return session?.dictionary(forKey: keyWithdrawalAddresses) as? [String: String] ?? [:]
        }
        set {
            session?.set(newValue, forKey: keyWithdrawalAddresses)
        }
    }
}
