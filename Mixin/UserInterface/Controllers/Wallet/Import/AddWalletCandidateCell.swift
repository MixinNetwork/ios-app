import UIKit

final class AddWalletCandidateCell: UICollectionViewCell, TokenProportionRepresentableCell {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var proportionStackView: UIStackView!
    @IBOutlet weak var selectedImageView: UIImageView!
    
    override var isSelected: Bool {
        didSet {
            if isSelected {
                selectedImageView.layer.borderWidth = 0
                selectedImageView.image = R.image.ic_selected()
            } else {
                selectedImageView.layer.borderWidth = 1
                selectedImageView.image = nil
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        contentStackView.setCustomSpacing(11, after: nameLabel)
        nameLabel.setFont(
            scaledFor: .systemFont(ofSize: 16, weight: .medium),
            adjustForContentSize: true
        )
        selectedImageView.layer.cornerRadius = 8
        selectedImageView.layer.masksToBounds = true
        selectedImageView.layer.borderColor = R.color.icon_tint_tertiary()!
            .resolvedColor(with: traitCollection)
            .cgColor
        selectedImageView.layer.borderWidth = 1
        selectedImageView.image = nil
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        selectedImageView.layer.borderColor = R.color.icon_tint_tertiary()!
            .resolvedColor(with: traitCollection)
            .cgColor
    }
    
    func load(candidate: WalletCandidate, index: Int) {
        nameLabel.text = R.string.localizable.common_wallet_index(index + 1)
        valueLabel.attributedText = candidate.value
        loadProportions(
            kind: .classic,
            tokens: candidate.tokens,
            usdBalanceSum: candidate.usdBalanceSum
        )
    }
    
}
