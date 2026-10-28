import UIKit
import MixinServices

final class WalletCollectibleCell: UICollectionViewCell {
    
    static let reuseIdentifier = "wallet_collectible"
    
    private let iconView = InscriptionIconView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        titleLabel.font = .scaledFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = R.color.text()
        titleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
        subtitleLabel.textColor = R.color.text_tertiary()
        subtitleLabel.adjustsFontForContentSizeCategory = true
        
        let labels = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        labels.axis = .vertical
        labels.spacing = 4
        contentView.addSubview(iconView)
        contentView.addSubview(labels)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(42)
            make.top.greaterThanOrEqualToSuperview().offset(4)
            make.bottom.lessThanOrEqualToSuperview().offset(-4)
        }
        labels.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(14)
            make.trailing.equalToSuperview().offset(-16)
            make.top.bottom.equalToSuperview().inset(6)
        }
        isAccessibilityElement = true
        accessibilityTraits = .button
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.prepareForReuse()
    }
    
    func load(item: InscriptionOutput) {
        iconView.content = item.inscription?.inscriptionContent
        iconView.setNeedsLayout()
        titleLabel.text = item.inscription?.collectionName ?? R.string.localizable.collectibles()
        subtitleLabel.text = item.inscription?.sequenceRepresentation ?? item.inscriptionHash
        accessibilityLabel = [titleLabel.text, subtitleLabel.text]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
    
}
