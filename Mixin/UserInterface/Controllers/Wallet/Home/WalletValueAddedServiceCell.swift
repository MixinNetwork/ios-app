import UIKit

protocol WalletValueAddedServiceCell: UICollectionViewCell {
    func load(account: CashAccount?)
    func load(account: EarnAccount?)
}

extension WalletValueAddedServiceCell {
    
    var balanceFormatStyle: Decimal.FormatStyle {
        .number
        .locale(.current)
        .precision(.fractionLength(0...2))
        .rounded(rule: .towardZero)
    }
    
}
