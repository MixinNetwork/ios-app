import UIKit

final class TransactionHistoryDateFilterView: TransactionHistoryFilterView {
    
    func reloadData(startDate: Date?, endDate: Date?) {
        label.text = DateFormatter.shortDatePeriod(from: startDate, to: endDate) ?? R.string.localizable.date()
    }
    
}
