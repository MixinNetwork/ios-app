import UIKit

class CountryCell: UITableViewCell {
    
    static let ReuseIdentifier = "CountryCell"
    
    @IBOutlet weak var flagImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var checkMarkImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = UIView()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if animated {
            UIView.beginAnimations(nil, context: nil)
            UIView.setAnimationDuration(0.25)
        }
        checkMarkImageView.alpha = selected ? 1 : 0
        if animated {
            UIView.commitAnimations()
        }
    }
    
}
