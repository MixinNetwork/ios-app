import UIKit

final class MnemonicPhraseCell: UICollectionViewCell {
    
    @IBOutlet weak var labelBackgroundView: UIView!
    @IBOutlet weak var label: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        labelBackgroundView.layer.masksToBounds = true
        labelBackgroundView.layer.cornerRadius = 16
    }
    
}
