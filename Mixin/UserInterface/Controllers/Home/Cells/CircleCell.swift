import UIKit

class CircleCell: UITableViewCell {
    
    @IBOutlet weak var circleImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var isSelectedImageView: UIImageView!
    @IBOutlet weak var unreadMessageCountLabel: RoundedInsetLabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        unreadMessageCountLabel.isHidden = selected
        isSelectedImageView.isHidden = !selected
    }
    
}
