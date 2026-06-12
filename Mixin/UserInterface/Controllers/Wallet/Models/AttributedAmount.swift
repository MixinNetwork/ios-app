import UIKit

enum AttributedAmount {
    
    static func attributedString(amount: String, symbol: String) -> NSAttributedString {
        var amount = amount
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
        let result = NSMutableAttributedString(string: amount, attributes: [
            .font: UIFontMetrics.default.scaledFont(for: .condensed(size: 32)),
            .foregroundColor: R.color.text()!,
        ])
        let attributedSymbol = NSAttributedString(string: "\u{2060} \u{2060}\(symbol)", attributes: [
            .font: UIFont.preferredFont(forTextStyle: .caption1),
            .foregroundColor: R.color.text()!,
        ])
        result.append(attributedSymbol)
        return result
    }
    
}
