import Foundation
import PassKit
import Frames
import Checkout3DS

enum BuyCryptoConfig {
    
    static let checkout3DSEnvironment: Checkout3DS.Environment = .production
    
    static let framesEnvironment: Frames.Environment = .live
    static let framesSchemes: [CardScheme] = [.visa, .mastercard, .americanExpress, .jcb]
    
    static let botUserID: String = "61cb8dd4-16b1-4744-ba0c-7b2d2e52fc59"
    static let host: String = "https://api.route.mixin.one"
    
    static let applePayNetworks: [PKPaymentNetwork] = [.visa, .masterCard, .amex, .JCB]
    static let applePayMerchantID = R.entitlements.comAppleDeveloperInAppPayments.merchantOneMixinMessenger
    
    static let supportedCards = "Visa, Mastercard, American Express, JCB"
    
}
