import UIKit

protocol DepositEntryActionDelegate: AnyObject {
    func depositEntryCell(_ cell: UICollectionViewCell, didRequestAction action: DepositViewModel.Entry.Action)
}
