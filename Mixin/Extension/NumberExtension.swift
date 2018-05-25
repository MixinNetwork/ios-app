import Foundation

extension NumberFormatter {

    static let balanceFormatter = NumberFormatter(numberStyle: .decimal, maximumFractionDigits: 8)
    static let legalTenderFormatter = NumberFormatter(numberStyle: .decimal, maximumFractionDigits: 2)
    static let decimal = NumberFormatter(numberStyle: .decimal)

    convenience init(numberStyle: NumberFormatter.Style) {
        self.init()
        self.numberStyle = numberStyle
    }

    convenience init(numberStyle: NumberFormatter.Style, maximumFractionDigits: Int) {
        self.init()
        self.numberStyle = numberStyle
        self.maximumFractionDigits = maximumFractionDigits
    }

    convenience init(numberStyle: NumberFormatter.Style, maximumFractionDigits: Int, alwaysShowsDecimalSeparator: Bool) {
        self.init()
        self.numberStyle = numberStyle
        self.maximumFractionDigits = maximumFractionDigits
        self.alwaysShowsDecimalSeparator = alwaysShowsDecimalSeparator
    }
}

extension Double {

    func toFormatLegalTender() -> String {
        return NumberFormatter.legalTenderFormatter.string(from: NSNumber(value: self)) ?? String(format: "%.2f", self)
    }

    func formatSimpleBalance() -> String {
        return NumberFormatter.balanceFormatter.string(from: NSNumber(value: self))?.formatSimpleBalance() ?? String(format: "%.6f", self)
    }
}
