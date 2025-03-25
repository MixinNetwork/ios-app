import Foundation
import MixinServices

enum FiatMoneyValueAttributedStringBuilder {
    
    static func attributedString(usdValue: Decimal, fontSize: CGFloat) -> NSAttributedString {
        var amount = CurrencyFormatter.localizedString(
            from: usdValue * Currency.current.decimalRate,
            format: .fiatMoney,
            sign: .never
        )
        if amount.count > 3 {
            var index = amount.index(amount.endIndex, offsetBy: -3)
            let beforeIndex = amount.index(before: index)
            let afterIndex = amount.index(after: index)
            if !amount[index].isNumber {
                // Avoid decimal separator or grouping separator being first character of the new line
                if beforeIndex == amount.startIndex {
                    index = afterIndex
                } else {
                    index = beforeIndex
                }
            }
            amount.insert("\u{200B}", at: index)
        }
        let attributedAmount = NSMutableAttributedString(string: amount, attributes: [
            .font: UIFontMetrics.default.scaledFont(for: .condensed(size: fontSize)),
            .foregroundColor: R.color.text()!,
        ])
        let symbol = NSAttributedString(string: "\u{2060} \u{2060}\(Currency.current.code)", attributes: [
            .font: UIFont.preferredFont(forTextStyle: .caption1),
            .foregroundColor: R.color.text_tertiary()!,
        ])
        attributedAmount.append(symbol)
        return attributedAmount
    }
    
}
