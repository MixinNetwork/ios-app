import UIKit

final class TokenTransactionDateHeaderView: UICollectionReusableView {
    
    private(set) weak var label: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.background()
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .caption1)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = R.color.text_quaternary()
        label.accessibilityTraits.insert(.header)
        addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.bottom.equalToSuperview().inset(14)
        }
        self.label = label
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard/Xib not supported")
    }
    
}
