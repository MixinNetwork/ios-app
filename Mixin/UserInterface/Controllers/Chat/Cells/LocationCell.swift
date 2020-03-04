import UIKit

class LocationCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    func render(location: NearbyLocationLoader.Location) {
        iconImageView.image = location.category.image
        titleLabel.text = location.name
        subtitleLabel.text = location.address
    }
    
}
