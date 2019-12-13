import UIKit

class SharedAppCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var infoView: PeerInfoView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        infoView.descriptionLabel.numberOfLines = 2
    }
    
}
