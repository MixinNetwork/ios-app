import Foundation

final class CheckoutAmountFormatter {
    
    let maximumIntegerDigits: Int
    let maximumFractionDigits: Int
    let fiatMoneyCeilingHandler: NSDecimalNumberHandler
    
    private let rate: Int
    
    private let fiatMoneyDisplayFormatter = NumberFormatter()
    private let assetDisplayFormatter = NumberFormatter()
    private let assetTransportFormatter = NumberFormatter()
    
    init(code: String) {
        let fullAmountCodes = [
            "BIF", "CLF", "DJF", "GNF", "ISK", "JPY", "KMF",
            "KRW", "PYG", "RWF", "UGX", "VUV", "VND", "XAF",
            "XOF", "XPF",
        ]
        let divideBy1000Codes = [
            "BHD", "IQD", "JOD", "KWD", "LYD", "OMR", "TND",
        ]
        
        let uppercasedCode = code.uppercased()
        if fullAmountCodes.contains(uppercasedCode) {
            maximumIntegerDigits = 9
            maximumFractionDigits = 0
            rate = 1
        } else if divideBy1000Codes.contains(uppercasedCode) {
            maximumIntegerDigits = 6
            maximumFractionDigits = 2
            rate = 1000
        } else if uppercasedCode == "CLP" {
            maximumIntegerDigits = 7
            maximumFractionDigits = 0
            rate = 100
        } else {
            maximumIntegerDigits = 7
            maximumFractionDigits = 2
            rate = 100
        }
        
        fiatMoneyCeilingHandler = NSDecimalNumberHandler(
            roundingMode: .up,
            scale: Int16(maximumFractionDigits),
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: true
        )
        
        fiatMoneyDisplayFormatter.numberStyle = .decimal
        fiatMoneyDisplayFormatter.maximumFractionDigits = maximumFractionDigits
        fiatMoneyDisplayFormatter.locale = .current
        fiatMoneyDisplayFormatter.usesGroupingSeparator = true
        
        assetDisplayFormatter.numberStyle = .decimal
        assetDisplayFormatter.maximumFractionDigits = 8
        assetDisplayFormatter.locale = .current
        assetDisplayFormatter.usesGroupingSeparator = true
        
        assetTransportFormatter.numberStyle = .decimal
        assetTransportFormatter.minimumFractionDigits = 0
        assetTransportFormatter.maximumFractionDigits = 8
        assetTransportFormatter.locale = .enUSPOSIX
        assetTransportFormatter.usesGroupingSeparator = false
    }
    
    func checkoutAmount(_ decimal: Decimal) -> Int {
        let number = NSDecimalNumber(decimal: decimal * Decimal(rate))
        return number.intValue
    }
    
    func fiatMoneyDisplayString(_ decimal: Decimal, minimumFractionDigits: Int = 0) -> String {
        fiatMoneyDisplayFormatter.minimumFractionDigits = minimumFractionDigits
        return fiatMoneyDisplayFormatter.string(from: decimal as NSDecimalNumber) ?? "\(decimal)"
    }
    
    func assetDisplayString(_ decimal: Decimal, minimumFractionDigits: Int = 0) -> String {
        assetDisplayFormatter.minimumFractionDigits = minimumFractionDigits
        return assetDisplayFormatter.string(from: decimal as NSDecimalNumber) ?? "\(decimal)"
    }
    
    func assetTransportString(_ decimal: Decimal) -> String {
        assetTransportFormatter.string(from: decimal as NSDecimalNumber) ?? "\(decimal)"
    }
    
}
