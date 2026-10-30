import UIKit
import MixinServices

final class WalletCollectibleCell: UICollectionViewCell {
    
    static let reuseIdentifier = "wallet_collectible"
    
    private let iconView = InscriptionIconView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        titleLabel.font = .preferredFont(forTextStyle: .callout)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = R.color.text()
        subtitleLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        subtitleLabel.textColor = R.color.text_tertiary()
        
        let labels = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        labels.axis = .vertical
        labels.spacing = 4
        contentView.addSubview(iconView)
        contentView.addSubview(labels)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(42)
        }
        labels.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(14)
            make.trailing.equalToSuperview().offset(-16)
            make.top.bottom.equalToSuperview().inset(4)
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
