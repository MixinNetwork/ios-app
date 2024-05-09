import UIKit

final class InscriptionHashCell: UITableViewCell {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var hashPatternView: InscriptionHashView!
    @IBOutlet weak var hashLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentStackView.setCustomSpacing(4, after: hashPatternView)
    }
    
}
