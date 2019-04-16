import UIKit

class RecentBotCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var label: UILabel!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.sd_cancelCurrentImageLoad()
    }
    
    func render(app: App) {
        imageView.sd_setImage(with: URL(string: app.iconUrl), completed: nil)
        label.text = app.name
    }
    
}
