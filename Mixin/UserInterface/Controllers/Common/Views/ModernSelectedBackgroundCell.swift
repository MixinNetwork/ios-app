import UIKit

class ModernSelectedBackgroundCell: UITableViewCell {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = SelectedCellBackgroundView()
    }
    
}
