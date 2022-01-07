import UIKit

class AlbumCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var dotImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let selectedBackgroundView = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        selectedBackgroundView.backgroundColor = R.color.album_selected()
        selectedBackgroundView.layer.cornerRadius = 12
        selectedBackgroundView.clipsToBounds = true
        self.selectedBackgroundView = selectedBackgroundView
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.sd_cancelCurrentImageLoad()
        dotImageView.isHidden = true
    }
    
}
