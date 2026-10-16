import UIKit

final class MnemonicPhraseCell: UICollectionViewCell {
    
    @IBOutlet weak var labelBackgroundView: UIView!
    @IBOutlet weak var label: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        if #available(iOS 26, *) {
            backgroundColor = .clear
        }
        labelBackgroundView.layer.masksToBounds = true
        labelBackgroundView.layer.cornerRadius = 16
    }
    
}
