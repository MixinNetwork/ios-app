import UIKit

class CountryCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var flagImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var codeLabel: UILabel!
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if let backgroundView = selectedBackgroundView {
            backgroundView.bounds.size.height = 50
            backgroundView.center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        }
    }
    
}
