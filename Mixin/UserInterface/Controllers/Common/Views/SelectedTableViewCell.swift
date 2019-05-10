import UIKit

class SelectedTableViewCell: UITableViewCell {

    override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = UIView.createSelectedBackgroundView()
    }

}
