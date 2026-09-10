import UIKit

final class SearchMarketResultsHeaderView: UICollectionReusableView {
    
    static let reuseIdentifier = "SearchMarketResultsHeader"
    
    private(set) weak var titleLabel: UILabel!
    private(set) weak var moreButton: UIButton!
    
    var showMoreResults: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubviews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSubviews()
    }
    
    private func loadSubviews() {
        backgroundColor = R.color.background()
        
        let titleLabel = UILabel()
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        titleLabel.textColor = R.color.text()
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
        }
        self.titleLabel = titleLabel
        
        var config: UIButton.Configuration = .plain()
        config.attributedTitle = AttributedString(
            string: R.string.localizable.more(),
            scalingByFontSize: 14
        )
        let moreButton = UIButton(configuration: config)
        moreButton.titleLabel?.adjustsFontForContentSizeCategory = true
        moreButton.addTarget(
            self,
            action: #selector(showMoreResults(_:)),
            for: .touchUpInside
        )
        addSubview(moreButton)
        moreButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8)
        }
        self.moreButton = moreButton
    }
    
    @objc private func showMoreResults(_ sender: Any) {
        showMoreResults?()
    }
    
}
