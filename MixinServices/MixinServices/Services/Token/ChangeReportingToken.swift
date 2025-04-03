import Foundation

public protocol ChangeReportingToken: Token {
    
    var decimalUSDChange: Decimal { get }
    var localizedUSDChange: String { get }
    
}

extension ChangeReportingToken {
    
    public func localizeUSDChange() -> String {
        NumberFormatter.percentage.string(decimal: decimalUSDChange) ?? ""
    }
    
}
