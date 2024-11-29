import UIKit

final class ExploreSegmentCell: UICollectionViewCell {
    
    @IBOutlet weak var label: InsetLabel!
    @IBOutlet weak var badgeView: BadgeDotView!
    
    override var isSelected: Bool {
        didSet {
            updateColors(isSelected: isSelected)
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        label.contentInset = UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        label.layer.borderWidth = 1
        label.layer.cornerRadius = 19
        label.layer.masksToBounds = true
        updateColors(isSelected: false)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors(isSelected: isSelected)
        }
    }
    
    private func updateColors(isSelected: Bool) {
        if isSelected {
            label.layer.borderColor = R.color.theme()!.cgColor
            label.textColor = R.color.theme()
            label.backgroundColor = R.color.background_selection()
        } else {
            label.layer.borderColor = R.color.line()!.cgColor
            label.textColor = R.color.text()
            label.backgroundColor = .clear
        }
    }
    
}
