import UIKit

class PhotoInputAlbumCell: UICollectionViewCell {
    
    @IBOutlet weak var textLabel: UILabel!
    
    private var cachedWidth: CGFloat?
    
    override var isSelected: Bool {
        didSet {
            textLabel.textColor = isSelected ? R.color.icon_fill()! : .accessoryText
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        cachedWidth = nil
    }
    
}
