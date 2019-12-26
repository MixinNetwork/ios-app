import UIKit

class PhotoInputAlbumCell: UICollectionViewCell {
    
    @IBOutlet weak var textLabel: UILabel!
    
    private var cachedWidth: CGFloat?
    
    override var isSelected: Bool {
        didSet {
            textLabel.textColor = isSelected ? R.color.icon_fill()! : .accessoryText
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        textLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        cachedWidth = nil
    }
    
}
