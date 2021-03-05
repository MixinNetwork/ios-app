import UIKit

class ModernSelectedBackgroundCell: UITableViewCell {
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectedBackgroundView = SelectedCellBackgroundView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        selectedBackgroundView = SelectedCellBackgroundView()
    }
    
}
