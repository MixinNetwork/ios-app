import UIKit

class UploadContactCell: UITableViewCell {
    
    static let height: CGFloat = 64
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = UIView.createSelectedBackgroundView()
    }
    
}
