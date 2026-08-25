import UIKit

protocol WalletValueAddedServiceCell: UICollectionViewCell {
    func load(account: CashAccount?)
    func load(account: EarnAccount?)
}
