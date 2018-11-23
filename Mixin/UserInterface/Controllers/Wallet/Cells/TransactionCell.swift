import UIKit

class TransactionCell: UITableViewCell {
    
    @IBOutlet weak var selectionView: RoundCornerSelectionView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        selectionView.setHighlighted(selected, animated: animated)
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        selectionView.setHighlighted(highlighted, animated: animated)
    }
    
}

class TopTransactionCell: TransactionCell {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionView.roundingCorners = [.topLeft, .topRight]
    }
    
}

class BottomTransactionCell: TransactionCell {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionView.roundingCorners = [.bottomLeft, .bottomRight]
    }
    
}
