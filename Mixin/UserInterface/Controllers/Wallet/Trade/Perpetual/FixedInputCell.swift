import UIKit

final class FixedInputCell: UICollectionViewCell {
    
    @IBOutlet weak var label: UILabel!
    
    override var isSelected: Bool {
        didSet {
            updateColors(isSelected: isSelected)
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        label.setFont(
            scaledFor: .systemFont(ofSize: 12, weight: .medium),
            adjustForContentSize: true
        )
        contentView.layer.borderWidth = 1
        contentView.layer.cornerRadius = bounds.height / 2
        contentView.layer.masksToBounds = true
        updateColors(isSelected: isSelected)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.layer.cornerRadius = bounds.height / 2
    }
    
    private func updateColors(isSelected: Bool) {
        if isSelected {
            contentView.layer.borderColor = R.color.theme()!.cgColor
            label.textColor = R.color.theme()
        } else {
            contentView.layer.borderColor = R.color.line()!.cgColor
            label.textColor = R.color.text()
        }
    }
    
}
