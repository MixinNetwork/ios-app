import UIKit

final class ModernSegmentCell: UICollectionViewCell {
    
    @IBOutlet weak var label: InsetLabel!
    @IBOutlet weak var badgeView: BadgeDotView!
    
    override var isSelected: Bool {
        didSet {
            updateColors(isSelected: isSelected, traitCollection: traitCollection)
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        label.contentInset = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        label.layer.borderWidth = 1
        label.layer.cornerRadius = 19
        label.layer.masksToBounds = true
        updateColors(isSelected: false, traitCollection: traitCollection)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors(isSelected: isSelected, traitCollection: traitCollection)
        }
    }
    
    private func updateColors(isSelected: Bool, traitCollection: UITraitCollection) {
        if isSelected {
            label.layer.borderColor = R.color.theme()!
                .resolvedColor(with: traitCollection)
                .cgColor
            label.textColor = R.color.theme()
            label.backgroundColor = .clear
        } else {
            label.layer.borderColor = R.color.line()!
                .resolvedColor(with: traitCollection)
                .cgColor
            label.textColor = R.color.text()
            label.backgroundColor = R.color.background()
        }
    }
    
}
