import UIKit

final class AddWalletCandidateCell: UICollectionViewCell, TokenProportionRepresentableCell {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var importedLabel: InsetLabel!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var proportionStackView: UIStackView!
    @IBOutlet weak var selectedImageView: UIImageView!
    
    override var isSelected: Bool {
        didSet {
            reloadSelectedImageView()
        }
    }
    
    private var alreadyImported = false {
        didSet {
            reloadSelectedImageView()
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
        importedLabel.text = R.string.localizable.wallet_candidate_imported()
        importedLabel.contentInset = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
        importedLabel.layer.cornerRadius = 4
        importedLabel.layer.masksToBounds = true
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
        alreadyImported = candidate.alreadyImported
        valueLabel.attributedText = candidate.value
        loadProportions(
            tokens: candidate.tokens,
            placeholder: .commonWalletChains,
            usdBalanceSum: candidate.usdBalanceSum
        )
    }
    
    private func reloadSelectedImageView() {
        if alreadyImported {
            importedLabel.isHidden = false
            selectedImageView.layer.borderWidth = 0
            selectedImageView.image = R.image.ic_deselected_high_contrast()
        } else if isSelected {
            importedLabel.isHidden = true
            selectedImageView.layer.borderWidth = 0
            selectedImageView.image = R.image.ic_selected()
        } else {
            importedLabel.isHidden = true
            selectedImageView.layer.borderWidth = 1
            selectedImageView.image = nil
        }
    }
    
}
