import UIKit

final class RecoveryKitFooterView: UIView {
    
    let label = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubviews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSubviews()
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let sizeToFitLabel = CGSize(width: size.width - 60, height: UIView.layoutFittingExpandedSize.height)
        let labelHeight = label.sizeThatFits(sizeToFitLabel)
        return CGSize(width: size.width, height: labelHeight.height + 40)
    }
    
    private func loadSubviews() {
        backgroundColor = R.color.background()
        label.backgroundColor = R.color.background()
        label.numberOfLines = 0
        label.textColor = R.color.error_red()
        label.textAlignment = .center
        label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        label.text = R.string.localizable.recovery_kit_attention()
        addSubview(label)
        label.snp.makeConstraints { make in
            make.top.greaterThanOrEqualToSuperview().offset(20).priority(.high)
            make.leading.equalToSuperview().offset(30)
            make.trailing.equalToSuperview().offset(-30)
            make.bottom.equalToSuperview()
        }
    }
    
}
