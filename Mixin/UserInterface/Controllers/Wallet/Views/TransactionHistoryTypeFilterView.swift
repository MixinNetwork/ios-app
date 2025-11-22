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
    
    func reloadData(type: Web3Transaction.DisplayType?) {
        label.text = switch type {
        case .none:
            R.string.localizable.all()
        case .receive:
            R.string.localizable.receive()
        case .send:
            R.string.localizable.send()
        case .swap:
            R.string.localizable.trade()
        case .approval:
            R.string.localizable.approval()
        case .pending:
            R.string.localizable.pending()
        }
    }
    
}
