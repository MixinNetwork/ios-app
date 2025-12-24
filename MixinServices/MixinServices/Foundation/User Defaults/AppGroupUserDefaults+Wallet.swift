import Foundation

extension AppGroupUserDefaults {
    
    public enum Wallet {
        
        enum Key: String, CaseIterable {
            case lastPINVerifiedDate = "last_pin_verified_date"
            case periodicPinVerificationInterval = "periodic_pin_verification_interval"
            
            case payWithBiometricAuthentication = "pay_with_biometric_auth"
            case biometricPaymentExpirationInterval = "biometric_payment_expiration_interval"
            
            case defaultTransferAssetId = "default_transfer_asset_id"
            case withdrawnAddressIds = "withdrawn_asset_ids"
            
            case currencyCode = "currency_code"
            
            /*
             The new transfer process requires using Outputs with a non-zero `sequence`. For locally created Outputs, the `sequence` is always zero, so there will be many unusable outputs in the database when user upgrades to this version, necessitating a full refresh. This flag is used to indicate whether the full refresh has been completed.
             Additionally, there was previously a variable called `inscriptionOutputsReloaded` used to indicate the result of a full refresh after adding the inscription_hash to Outputs. Since the update to `sequence` now requires another full refresh, this previous flag is no longer relevant (as only one refresh is needed), and thus it has been removed.
             */
            case outputSequencesReloaded = "output_sequences_reloaded"
            
            case swapTokens = "swap_tokens"
            case tradeMode = "trade_mode"
            case lastSelectedCategory = "last_selected_category"
            case lastSelectedWallet = "last_selected_wallet"
            case dappConnectionWalletID = "dapp_connection_wallet_id"
            
            case hasViewedPrivacyWalletTip = "has_viewed_privacy_wallet_tip"
            case hasViewedClassicWalletTip = "has_viewed_classic_wallet_tip"
            case hasViewedSafeWalletTip = "has_viewed_safe_wallet_tip"
            
            case lastBuyingAssetID = "last_buy_asset"
            case lastBuyingCurrencyCode = "last_buy_currency"
        }
        
        public static let didChangeWalletTipNotification = Notification.Name(rawValue: "one.mixin.services.DidChangeWalletTip")
        
        @Default(namespace: .wallet, key: Key.lastPINVerifiedDate, defaultValue: nil)
        public static var lastPINVerifiedDate: Date?
        
        @Default(namespace: .wallet, key: Key.periodicPinVerificationInterval, defaultValue: 0)
        public static var periodicPinVerificationInterval: TimeInterval
        
        @Default(namespace: .wallet, key: Key.payWithBiometricAuthentication, defaultValue: false)
        public static var payWithBiometricAuthentication: Bool
        
        @Default(namespace: .wallet, key: Key.biometricPaymentExpirationInterval, defaultValue: 60 * 120)
        public static var biometricPaymentExpirationInterval: TimeInterval
        
        @Default(namespace: .wallet, key: Key.defaultTransferAssetId, defaultValue: nil)
        public static var defaultTransferAssetId: String?
        
        @Default(namespace: .wallet, key: Key.withdrawnAddressIds, defaultValue: [:])
        public static var withdrawnAddressIds: [String: Bool]
        
        @Default(namespace: .wallet, key: Key.currencyCode, defaultValue: nil)
        public static var currencyCode: String?
        
        @Default(namespace: .wallet, key: Key.outputSequencesReloaded, defaultValue: false)
        public static var areOutputSequencesReloaded: Bool
        
        @Default(namespace: .wallet, key: Key.swapTokens, defaultValue: [])
        public static var swapTokens: [String]
        
        @Default(namespace: .wallet, key: Key.tradeMode, defaultValue: 0)
        public static var tradeMode: Int
        
        @Default(namespace: .wallet, key: Key.lastSelectedCategory, defaultValue: 0)
        public static var lastSelectedCategory: Int
        
        @RawRepresentableDefault(namespace: .wallet, key: Key.lastSelectedWallet, defaultValue: .privacy)
        public static var lastSelectedWallet: MixinServices.Wallet.Identifier
        
        @Default(namespace: .wallet, key: Key.dappConnectionWalletID, defaultValue: nil)
        public static var dappConnectionWalletID: String?
        
        @Default(namespace: .wallet, key: Key.hasViewedPrivacyWalletTip, defaultValue: false)
        public static var hasViewedPrivacyWalletTip: Bool {
            didSet {
                NotificationCenter.default.post(onMainThread: didChangeWalletTipNotification, object: self)
            }
        }
        
        @Default(namespace: .wallet, key: Key.hasViewedClassicWalletTip, defaultValue: false)
        public static var hasViewedClassicWalletTip: Bool {
            didSet {
                NotificationCenter.default.post(onMainThread: didChangeWalletTipNotification, object: self)
            }
        }
        
        @Default(namespace: .wallet, key: Key.hasViewedSafeWalletTip, defaultValue: false)
        public static var hasViewedSafeWalletTip: Bool {
            didSet {
                NotificationCenter.default.post(onMainThread: didChangeWalletTipNotification, object: self)
            }
        }
        
        @Default(namespace: .user, key: Key.lastBuyingAssetID, defaultValue: nil)
        public static var lastBuyingAssetID: String?
        
        @Default(namespace: .user, key: Key.lastBuyingCurrencyCode, defaultValue: nil)
        public static var lastBuyingCurrencyCode: String?
        
        internal static func migrate() {
            lastPINVerifiedDate = Date(timeIntervalSince1970: WalletUserDefault.shared.lastInputPinTime)
            periodicPinVerificationInterval = WalletUserDefault.shared.checkPinInterval
            
            payWithBiometricAuthentication = WalletUserDefault.shared.isBiometricPay
            biometricPaymentExpirationInterval = WalletUserDefault.shared.pinInterval
            
            defaultTransferAssetId = WalletUserDefault.shared.defalutTransferAssetId
            currencyCode = WalletUserDefault.shared.currencyCode
        }
        
    }
    
}
