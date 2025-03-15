import UIKit
import MixinServices

final class TransactionHistoryTypeFilterView: TransactionHistoryFilterView {
    
    func reloadData(type: SafeSnapshot.DisplayType?) {
        label.text = switch type {
        case .none:
            R.string.localizable.all()
        case .transfer:
            R.string.localizable.transfer()
        case .deposit:
            R.string.localizable.deposit()
        case .withdrawal:
            R.string.localizable.withdrawal()
        case .pending:
            R.string.localizable.pending()
        }
    }
    
    func reloadData(type: Web3Transaction.TransactionType?) {
        label.text = switch type {
        case .none:
            R.string.localizable.all()
        case .receive:
            R.string.localizable.deposit()
        case .send:
            R.string.localizable.withdrawal()
        case .other:
            R.string.localizable.other()
        case .contract:
            R.string.localizable.contract()
        }
    }
    
}
