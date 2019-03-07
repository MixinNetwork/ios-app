import UIKit

class CountryCell: UITableViewCell {
    
    static let ReuseIdentifier = "CountryCell"
    
    @IBOutlet weak var flagImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var checkView: CheckmarkView!

    override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = UIView.createSelectedBackgroundView()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        checkView.status = selected ? .selected : .unselected
    }
    
}
