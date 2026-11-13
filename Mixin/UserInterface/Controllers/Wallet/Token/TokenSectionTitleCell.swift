import UIKit

final class TokenSectionTitleCell: UICollectionViewCell {
    
    private(set) weak var label: UILabel!
    private(set) weak var disclosureIndicatorView: UIImageView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.background()
        
        let label = UILabel()
        label.textColor = R.color.text()
        label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let disclosure = UIImageView(image: R.image.ic_accessory_disclosure())
        disclosure.contentMode = .scaleAspectFit
        disclosure.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        let stack = UIStackView(arrangedSubviews: [label, disclosure])
        stack.spacing = 20
        contentView.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(5)
        }
        self.label = label
        self.disclosureIndicatorView = disclosure
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard/Xib not supported")
    }
    
}
