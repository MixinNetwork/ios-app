import UIKit

final class TradeViewAllFooterView: UICollectionReusableView {
    
    static let reuseIdentifier = "trade_view_all"
    
    var onViewAll: ((UIView) -> Void)?
    
    private(set) weak var viewAllButton: UIButton!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubviews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addSubviews()
    }
    
    @objc private func viewAll(_ sender: UIButton) {
        onViewAll?(self)
    }
    
    private func addSubviews() {
        backgroundColor = R.color.background()
        layer.cornerRadius = 8
        layer.masksToBounds = true
        
        var config: UIButton.Configuration = .plain()
        config.titleAlignment = .center
        var attributes = AttributeContainer()
        attributes.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14))
        attributes.foregroundColor = R.color.theme()
        config.attributedTitle = AttributedString(R.string.localizable.view_all(), attributes: attributes)
        let viewAllButton = UIButton(configuration: config)
        addSubview(viewAllButton)
        viewAllButton.snp.makeConstraints { make in
            make.height.width.greaterThanOrEqualTo(44)
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(10)
        }
        viewAllButton.addTarget(self, action: #selector(viewAll(_:)), for: .touchUpInside)
        self.viewAllButton = viewAllButton
    }
    
}
